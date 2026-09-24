# Egregore library — helpers for type and projection authors.
{ lib }:
let
  inherit (lib) mkOption types mkIf;
in rec {

  # ── Type authoring ──────────────────────────────────────────────────
  #
  # Declare an entity type from within a module function. Returns a
  # module body (attrset with options + config), not a module function.
  #
  # Usage (in a type file):
  #
  #   { lib, egregorLib, config, ... }:
  #   egregorLib.mkType {
  #     name = "routeros";
  #     description = "MikroTik RouterOS switch";
  #     options = {
  #       model = lib.mkOption { type = lib.types.str; default = ""; };
  #     };
  #     deriveOptions = {
  #       address = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
  #     };
  #     derive = name: entityConfig: egregore: {
  #       address = entityConfig.routeros.model;
  #     };
  #   }
  #
  # The `options` attrset is placed under `entities.<name>.<typeName>.*`.
  # All options must have defaults (entities of other types see them).
  #
  # `deriveOptions` declares the entity's derived keys — top-level entity
  # options (the aspect namespace), beside the kind. Every key `derive`
  # writes must be declared here (or in another module's deriveOptions/
  # options): derived keys are closed and checked, there is no open bag.
  # A key computed by several kinds is declared in each of them with the
  # SAME type; exactly one declaration may carry default/description
  # (the module system rejects duplicates of those), the rest are bare
  # `mkOption { type = ...; }`.
  #
  # derive/relations/verbs/assertions receive three arguments:
  #   name       — the entity's name
  #   config     — the entity's config (includes config.<typeName>)
  #   egregore   — the top-level egregore config, arriving as the
  #                `egregore` module argument of the entity submodule
  #                (model §9) and passed through to the hooks
  #
  mkType = {
    name,
    description ? "",
    options ? {},
    deriveOptions ? {},
    # Resolved outbound edges, by ref name. `refs` is what the author
    # wrote; this is what it resolves to once type defaults (site
    # fallback, family defaults) are applied. Core inverts it into
    # refsIn alongside raw refs, so the inverse index is complete
    # even when the edge was inherited rather than written.
    relations ? _name: _config: _egregore: {},
    derive ? _name: _config: _egregore: {},
    verbs ? _name: _config: _egregore: {},
    assertions ? _name: _config: _egregore: [],
  }:
    let
      typeName = name;
      mod = {
        options = {
          ${typeName} = mkOption {
            type = types.nullOr (types.submodule { inherit options; });
            default = null;
          };
        } // deriveOptions;
      };
    in {
      config.types.${typeName} = { inherit description; };

      options.entities = mkOption {
        type = types.attrsWith {
          lazy = true;
          placeholder = "id";
          elemType = types.submodule ({ config, name, egregore, ... }: {
            imports = [ mod ];

            config = mkIf (config.${typeName} != null) ({
              relations = relations name config egregore;
              verbs = verbs name config egregore;
              assertions = assertions name config egregore;
            } // derive name config egregore);
          });
        };
      };
    };

  # Extend an existing type with more options/derived keys/assertions.
  #
  # The module system merges a nested option declaration into an existing
  # submodule option, so an extension contributes `options.<type>.<field>`
  # alongside the base type's `options.<type> = mkOption { … }`. The base
  # type's module and this one must have the same submodule shape (same
  # `functionArgs`) for the merge to take; both use
  # `{ config, name, egregore, ... }`. The type itself is registered by
  # the base, so this does not touch `config.types`. `deriveOptions` are
  # top-level entity options, same as in `mkType`.
  mkTypeExtend = {
    name,
    options ? {},
    deriveOptions ? {},
    derive ? _name: _config: _egregore: {},
    relations ? _name: _config: _egregore: {},
    verbs ? _name: _config: _egregore: {},
    assertions ? _name: _config: _egregore: [],
  }:
    let
      typeName = name;
    in {
      options.entities = mkOption {
        type = types.attrsWith {
          lazy = true;
          placeholder = "id";
          elemType = types.submodule ({ config, name, egregore, ... }: {
            options = {
              ${typeName} = mkOption {
                type = types.nullOr (types.submodule { inherit options; });
              };
            } // deriveOptions;

            config = mkIf (config.${typeName} != null) ({
              relations = relations name config egregore;
              verbs = verbs name config egregore;
              assertions = assertions name config egregore;
            } // derive name config egregore);
          });
        };
      };
    };

  # A facet aspect: contributes *top-level* options on the entity (not a
  # kind bag). It registers nothing and writes no kind; presence is
  # whatever the caller's `derive` gates on. This is how a cross-cutting
  # concern (routing, monitoring, …) attaches to any entity without
  # being nested under a kind. Derived keys are declared in `options`
  # (already top-level here) and written by `derive`, whose returned
  # attrset is spread into the entity's top-level config.
  mkAspect = {
    options ? {},
    relations ? _name: _config: _egregore: {},
    derive ? _name: _config: _egregore: {},
    assertions ? _name: _config: _egregore: [],
  }: {
    options.entities = mkOption {
      type = types.attrsWith {
        lazy = true;
        placeholder = "id";
        elemType = types.submodule ({ config, name, egregore, ... }: {
          inherit options;

          config = {
            relations = relations name config egregore;
            assertions = assertions name config egregore;
          } // derive name config egregore;
        });
      };
    };
  };

  # ── Refs ────────────────────────────────────────────────────────────
  #
  # A ref is an edge to another entity. Two spellings, one meaning:
  #
  #   refs.gateway = "some-router";
  #   refs.peer    = { target = "a-switch"; port = "port9"; };
  #
  # The plain form names the far entity and nothing else. The rich form
  # additionally names *where* on the far entity the edge lands — a
  # switch port, a host NIC — which is what lets an edge be checked
  # rather than merely described. Both are the same edge; `refTarget`
  # answers "who" for either, so a reader that only cares about the
  # target never has to know which spelling was used.
  #
  # Rich refs are strictly additive: every existing `refs.x = "name"`
  # keeps reading back as that same string.
  #
  # The normalized edge shape (`refNorm` output, and the value of the
  # entity's `edges` aspect): one attrset per edge, whichever spelling
  # the ref used.
  edgeType = types.submodule {
    options = {
      target = mkOption {
        type = types.str;
        description = "Name of the entity this edge points at.";
      };
      port = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Port on the target this edge lands on, when the target is a
          switch. Names a key in the target's `ports` attrset.
        '';
      };
      nic = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Interface on the target this edge lands on, when the target is
          a host. Names a key in the target's `host.interfaces`.
        '';
      };
    };
  };

  refType = types.either types.str edgeType;

  # The far entity's name, whichever spelling the ref used.
  refTarget = ref: if builtins.isString ref then ref else ref.target;

  # Rich form for either spelling — for consumers that want one shape.
  refNorm = ref:
    if builtins.isString ref
    then { target = ref; port = null; nic = null; }
    else ref;

  # ── Exposure refs ───────────────────────────────────────────────────
  #
  # An offering runs on an exposure (model §5); the ref names the node
  # (target) and the exposure on it. The exposure's name gives the
  # exposure its identity (§6) — an offering refs an exposure by name.
  exposureRefType = types.submodule {
    options = {
      target = mkOption {
        type = types.str;
        description = "Name of the node entity that holds the exposure.";
      };
      exposure = mkOption {
        type = types.str;
        description = "Name of the exposure on the target entity.";
      };
    };
  };

  # The node the ref names, for readers that only care which node runs
  # the offering.
  exposureTarget = ref: ref.target;

  # ── Querying ────────────────────────────────────────────────────────

  # The type of an entity is the name of the kind that is present
  # (model §4); no field stores it. A kind is present when its option
  # value is not null — `e.host != null` is "this is a host".
  withKind = kindName: entities:
    lib.filterAttrs (_: e: (e.${kindName} or null) != null) entities;

  # Deprecated alias for `withKind` — dispatch on kind presence.
  ofType = withKind;

  tagged = tag: entities:
    lib.filterAttrs (_: e: builtins.elem tag e.tags) entities;

  # Presence is "declared and non-null": for a nullOr aspect that is
  # exactly "the aspect is present" (model §4), and for a closed key
  # with a non-null default it is "the key exists" — the same sets as
  # the old open-bag `attrs ? k && attrs.k != null` produced.
  withAttr = attrName: entities:
    lib.filterAttrs (_: e: e ? ${attrName} && e.${attrName} != null) entities;

  # A capability is just an aspect key whose schema is its contract;
  # these are the query spelling. `withAspect "ssh"` is "everything
  # sshable".
  withAspect = withAttr;
  hasAspect = attrName: e: e ? ${attrName} && e.${attrName} != null;

  collectAttr = attrName: entities:
    lib.mapAttrs (_: e: e.${attrName}) (withAttr attrName entities);

  refsOf = entity: allEntities:
    lib.mapAttrs (_: ref: allEntities.${refTarget ref}) entity.refs;

  referencedBy = targetName: entities:
    lib.filterAttrs (_: e:
      builtins.any (ref: refTarget ref == targetName) (builtins.attrValues e.refs)
    ) entities;

  withVerb = verbName: entities:
    lib.filterAttrs (_: e: e.verbs ? ${verbName}) entities;

  # ── Exposures ─────────────────────────────────────────────────────
  #
  # An exposure is a named listener reservation on a node (model §6).
  # Its name is its identity; its role says which projection reads it
  # (§8.5). Written as data or computed (exporter exposures derive from
  # tags and ha-group membership), same structure either way, in the
  # one `exposures` aspect. `exposuresOf` is the reading spelling.
  exposuresOf = entity: entity.exposures or {};

  # Everything holding an exposure of the given role.
  withRole = role: entities:
    lib.filterAttrs (_: e:
      builtins.any (x: (x.role or null) == role)
        (builtins.attrValues (exposuresOf e))
    ) entities;

  # ── Spec interceptor ────────────────────────────────────────────────
  #
  # An interceptor (for the pedestal-style spec system in
  # `nixclyx/lib/spec`) that turns an `egregoreType` spec field
  # into an `imports` entry calling `mkType` at module-eval time.
  #
  # A spec may instead declare `extends = "<type>"` to contribute to an
  # existing type; that routes to `mkTypeExtend`.
  #
  # `egregoreType` is a function of moduleArgs (giving the type body
  # access to lib, egregorLib, config) returning the mkType-config
  # attrset. The top graph is not threaded through here: the entity
  # submodule passes it to every aspect module as the `egregore` module
  # argument (model §9), and `mkType` hands it to the derive/relations/
  # verbs/assertions hooks as their third argument:
  #
  #   {
  #     egregoreType = { lib, egregorLib, config, ... }: {
  #       name = "site";
  #       description = "...";
  #       options = { domain = lib.mkOption { ... }; ... };
  #       deriveOptions = { label = lib.mkOption { ... }; ... };
  #       derive = name: entity: egregore: { ... };
  #     };
  #   }
  #
  # A plain attrset is also accepted for types that don't need lib in
  # their derive/verbs/assertions bodies.
  interceptors.egregoreType = {
    enter = bundle:
      if !(bundle.value ? egregoreType) then bundle
      else
        let
          etype = bundle.value.egregoreType;
          typeModule = moduleArgs:
            let
              inherit (moduleArgs) egregorLib;
              resolved = if builtins.isFunction etype then etype moduleArgs else etype;
            in
              if resolved ? extends
              then egregorLib.mkTypeExtend
                ((builtins.removeAttrs resolved [ "extends" ]) // {
                  name = resolved.extends;
                })
              else egregorLib.mkType resolved;
        in bundle // {
          value = (builtins.removeAttrs bundle.value ["egregoreType"]) // {
            imports = (bundle.value.imports or []) ++ [ typeModule ];
          };
        };
  };

  # An `egregoreAspect` spec field: a facet contributing top-level entity
  # options (see `mkAspect`). Same shape as a type spec, but registers
  # nothing and writes no kind.
  #
  #   { egregoreAspect = { lib, config, ... }: {
  #       options = { vpn = lib.mkOption { ... }; };
  #       derive = name: entity: egregore: { ... };
  #   }; }
  interceptors.egregoreAspect = {
    enter = bundle:
      if !(bundle.value ? egregoreAspect) then bundle
      else
        let
          etype = bundle.value.egregoreAspect;
          aspectModule = moduleArgs:
            let
              inherit (moduleArgs) egregorLib;
              resolved = if builtins.isFunction etype then etype moduleArgs else etype;
            in egregorLib.mkAspect resolved;
        in bundle // {
          value = (builtins.removeAttrs bundle.value ["egregoreAspect"]) // {
            imports = (bundle.value.imports or []) ++ [ aspectModule ];
          };
        };
  };
}
