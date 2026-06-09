# Module spec compiler — pedestal-style interceptors over a default
# spec→module builder.
#
# A spec is data: `{path, gate, description, options, extraOptions,
# config, imports, variant}`. The compiler turns it into a NixOS-shaped
# module function `moduleArgs → {imports, options, config}`.
#
# The four behaviors that used to be baked into `mkModule` (path
# wrapping, `description→enable` synthesis, `gate` keyword translation,
# `variant` enum grouping) live as separate **interceptors**. Each
# interceptor is an attrset with three optional hooks:
#
#   enter    : bundle → bundle    (per spec, forward order)
#   leave    : bundle → bundle    (per spec, reverse order — stack pop)
#   finalize : ctx → [module]     (once per collection)
#
# A `bundle` is `{ctx, value}` where `ctx` is shared cross-interceptor
# state and `value` is the spec-becoming-module. `enter`s run forward,
# `leave`s run in reverse (matching Pedestal's stack semantics), and
# `finalize`s fire after all specs in a collection have been walked.
#
# `mkModule spec` compiles one spec using the default interceptor list.
# `compileSpecs { interceptors?, specs }` threads ctx across a list and
# appends `finalize` output, which is what you want for variant-style
# cross-spec emission.
#
# Backwards compatibility: `mkModule spec moduleArgs` has the same
# signature and output as the previous version, so existing call sites
# (including `nixclyx/lib/fs.nix:compileSpecs`) keep working unchanged.
#
# This file imports nothing — all `lib.*` calls live inside the
# moduleArgs lambdas of the returned module functions, where `lib`
# is already available from the module system. Compile-time list
# work (chain walking, variant accumulation) uses `builtins` only.
let
  inherit (builtins) isFunction foldl' elemAt genList length attrValues map;

  id = x: x;

  last = l: elemAt l (length l - 1);
  init = l: genList (elemAt l) (length l - 1);

  reverseList = l:
    let n = length l;
    in genList (i: elemAt l (n - i - 1)) n;

  # ── default builder ────────────────────────────────────────────────
  #
  # Turn a (possibly-interceptor-transformed) spec-shaped value into a
  # NixOS module. Options/config may be functions of `moduleArgs`; the
  # builder evaluates them at module-eval time.

  # Resolve a possibly-function spec field, substituting `default` for
  # both "the field was null" and "the function returned null" (a
  # function wrapper introduced by an earlier interceptor may have
  # propagated a null input as a null result).
  evalOr = default: x: moduleArgs:
    let
      raw =
        if x == null then null
        else if isFunction x then x moduleArgs
        else x;
    in
      if raw == null then default else raw;

  defaultBuilder = value: moduleArgs: {
    imports = value.imports or [];
    options = evalOr {} (value.options or {}) moduleArgs;
    config  = evalOr {} (value.config  or {}) moduleArgs;
  };

  # ── path interceptor ──────────────────────────────────────────────
  #
  # Reads `spec.path`. On enter: stash the path in ctx, and wrap the
  # spec's options/config functions so they receive `cfg` in args (the
  # config slice rooted at `path`). On leave: wrap the produced
  # options under `path`, then merge with `extraOptions` (which live
  # outside the path).

  pathInterceptor = {
    enter = bundle:
      let path = bundle.value.path or []; in
      if path == [] then bundle
      else
        let
          injectCfg = origFn: moduleArgs:
            let
              cfg = moduleArgs.lib.attrByPath path {} moduleArgs.config;
              args = moduleArgs // { inherit cfg; };
            in
              if origFn == null then null
              else if isFunction origFn then origFn args
              else origFn;
        in bundle // {
          ctx = bundle.ctx // { inherit path; };
          value = bundle.value // {
            options = injectCfg (bundle.value.options or null);
            config  = injectCfg (bundle.value.config  or null);
          };
        };

    leave = bundle:
      let
        path = bundle.ctx.path or [];
        extraFn = bundle.value.extraOptions or null;
      in
        if path == [] && extraFn == null then bundle
        else bundle // {
          value = bundle.value // {
            options = moduleArgs:
              let
                inherit (moduleArgs) lib;
                opts = evalOr {} (bundle.value.options or null) moduleArgs;
                extra = evalOr {} extraFn moduleArgs;
                wrapped =
                  if path == [] then opts
                  else if opts == {} && !(bundle.ctx.hasEnable or false) then {}
                  else lib.setAttrByPath path opts;
              in lib.recursiveUpdate wrapped extra;
          };
        };
  };

  # ── enable interceptor ────────────────────────────────────────────
  #
  # When `spec.description` is set (and there's no `variant`), synthesize
  # an `enable` option under the spec's path. The actual `mkIf cfg.enable`
  # wrapping is the gate interceptor's job; this one only declares.

  enableInterceptor = {
    enter = bundle:
      let
        hasVariant = bundle.value ? variant;
        desc = bundle.value.description or null;
        hasEnable = !hasVariant && desc != null;
      in bundle // {
        ctx = bundle.ctx // {
          inherit hasEnable;
          description = if hasEnable then desc else (bundle.ctx.description or null);
        };
      };

    leave = bundle:
      if !(bundle.ctx.hasEnable or false) then bundle
      else bundle // {
        value = bundle.value // {
          options = moduleArgs:
            let
              inherit (moduleArgs) lib;
              opts = evalOr {} (bundle.value.options or null) moduleArgs;
            in opts // { enable = lib.mkEnableOption bundle.ctx.description; };
        };
      };
  };

  # ── gate interceptor ──────────────────────────────────────────────
  #
  # Translates `spec.gate` keyword into the final `mkIf` wrapping on
  # `spec.config`. Recognizes:
  #
  #   "always"             — no wrapping (gate = false internally)
  #   "enable"             — mkIf cfg.enable (gate = true internally)
  #   args → bool function — mkIf (gate args)
  #
  # When unset, defaults to `true` if `description` is present (enables
  # the auto-enable behavior), otherwise `false`.
  #
  # If the variant interceptor has already populated `ctx.gate` with a
  # variant selector function, that takes precedence.

  gateInterceptor = {
    enter = bundle:
      let
        hasVariant = bundle.value ? variant;
        explicit = bundle.value ? gate;
        rawGate = bundle.value.gate or null;
        computed =
          if hasVariant then null  # variant interceptor sets ctx.gate
          else if explicit then
            (if builtins.isBool rawGate then
              throw "spec at ${builtins.concatStringsSep "." (bundle.value.path or [])}: gate booleans are removed. Use \"always\" (was false) or \"enable\" (was true)."
            else if rawGate == "always" then false
            else if rawGate == "enable" then true
            else rawGate)
          else if (bundle.value.description or null) != null then true
          else false;
      in bundle // {
        ctx = bundle.ctx // { gate = computed; };
      };

    leave = bundle:
      bundle // {
        value = bundle.value // {
          config = moduleArgs:
            let
              inherit (moduleArgs) lib;
              path = bundle.ctx.path or [];
              cfg = lib.attrByPath path {} moduleArgs.config;
              args = moduleArgs // { inherit cfg; };
              body = evalOr null (bundle.value.config or null) moduleArgs;
              gate = bundle.ctx.gate;
            in
              if body == null then {}
              else if gate == false then body
              else if gate == true then lib.mkIf cfg.enable body
              else if isFunction gate then lib.mkIf (gate args) body
              else body;
        };
      };
  };

  # ── variant interceptor ───────────────────────────────────────────
  #
  # When `spec.variant` is set, the spec is one of several alternatives
  # selected by an enum option declared at the parent path. The variant
  # name is the last segment of `spec.path`; the enum option name is
  # the last segment of `spec.variant`; the enum is declared at the
  # init of `spec.variant`.
  #
  # On enter: accumulate this variant into `ctx.variants` and override
  # `ctx.gate` so the spec's config is only active when the enum
  # selector picks this variant.
  #
  # On finalize: emit one module per parent path that declares the
  # enum option with all collected variant names. Only invoked by
  # `compileSpecs`; consumers that call `mkModule` per spec (like the
  # legacy fs.nix path) must synthesize the enum option themselves.

  variantInterceptor = {
    enter = bundle:
      let v = bundle.value.variant or null; in
      if v == null then bundle
      else
        let
          parentKey = builtins.concatStringsSep "." v;
          parentPath = init v;
          optName = last v;
          variantName = last bundle.value.path;
          existing = bundle.ctx.variants or {};
          forParent = existing.${parentKey} or {
            inherit parentPath optName;
            names = [];
          };
        in bundle // {
          ctx = bundle.ctx // {
            variants = existing // {
              ${parentKey} = forParent // {
                names = forParent.names ++ [variantName];
              };
            };
            gate = args: args.lib.getAttrFromPath v args.config == variantName;
          };
        };

    finalize = ctx:
      map (vrec:
        {lib, ...}: {
          options = lib.setAttrByPath vrec.parentPath {
            ${vrec.optName} = lib.mkOption {
              type = lib.types.enum vrec.names;
            };
          };
        }
      ) (attrValues (ctx.variants or {}));
  };

  # ── default interceptor list ──────────────────────────────────────
  #
  # Order matters: path runs first so other interceptors can read
  # `ctx.path`; enable runs before gate so gate's mkIf can rely on
  # ctx.hasEnable; variant runs last in enter so it can override
  # ctx.gate after gate.enter has computed the default.
  #
  # Leaves run in reverse: variant.leave (no-op) → gate.leave wraps
  # config → enable.leave adds enable to options → path.leave wraps
  # the whole options dict under path.

  defaultInterceptors = [
    pathInterceptor
    enableInterceptor
    gateInterceptor
    variantInterceptor
  ];

  # ── driver ────────────────────────────────────────────────────────

  runOne = {
    interceptors ? defaultInterceptors,
    spec,
    prevCtx ? {},
  }:
    let
      bundle0 = { ctx = prevCtx; value = spec; };
      bundle1 = foldl' (b: ix: (ix.enter or id) b) bundle0 interceptors;
      bundle2 = foldl' (b: ix: (ix.leave or id) b) bundle1 (reverseList interceptors);
    in bundle2;

  # Compile a single spec into a module function. Drop-in replacement
  # for the previous mkModule.
  #
  # The outer function signature destructures the standard module args
  # so NixOS's evalModules can introspect via `functionArgs` and know
  # to pass them. A bare `moduleArgs: ...` returns empty `functionArgs`,
  # which causes NixOS to pass nothing — breaking specs whose options
  # or config functions take `pkgs` (etc.). The `@` alias keeps the
  # full passed attrset available for forwarding to interceptor-wrapped
  # functions.
  mkModule = spec: {
    config ? null,
    lib ? null,
    pkgs ? null,
    options ? null,
    nixclyx ? null,
    ...
  } @ moduleArgs:
    let bundle = runOne { inherit spec; };
    in defaultBuilder bundle.value moduleArgs;

  # Compile a list of specs, threading ctx across them and appending
  # any modules emitted by `finalize` hooks. Use this entry point when
  # you want variant-style cross-spec emission to be handled by the
  # interceptor framework rather than by the collector.
  compileSpecs = {
    interceptors ? defaultInterceptors,
    specs,
  }:
    let
      step = acc: spec:
        let r = runOne { inherit interceptors spec; prevCtx = acc.ctx; };
        in {
          ctx = r.ctx;
          modules = acc.modules ++ [ (defaultBuilder r.value) ];
        };
      walked = foldl' step { ctx = {}; modules = []; } specs;
      extra = builtins.concatLists
        (map (ix: (ix.finalize or (_: [])) walked.ctx) interceptors);
    in walked.modules ++ extra;
in {
  inherit
    mkModule
    compileSpecs
    runOne
    defaultBuilder
    defaultInterceptors
    last
    init
    ;
  interceptors = {
    path = pathInterceptor;
    enable = enableInterceptor;
    gate = gateInterceptor;
    variant = variantInterceptor;
  };
}
