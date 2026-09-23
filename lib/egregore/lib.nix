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
  #     topConfig = config;
  #     description = "MikroTik RouterOS switch";
  #     options = {
  #       model = lib.mkOption { type = lib.types.str; default = ""; };
  #     };
  #     attrs = name: entityConfig: topConfig: {
  #       address = entityConfig.routeros.model;
  #     };
  #   }
  #
  # The `options` attrset is placed under `entities.<name>.<typeName>.*`.
  # All options must have defaults (entities of other types see them).
  #
  # attrs/verbs/assertions receive three arguments:
  #   name       — the entity's name
  #   config     — the entity's config (includes config.<typeName>)
  #   topConfig  — the top-level egregore config
  #
  mkType = {
    name,
    topConfig ? {},
    description ? "",
    options ? {},
    # Resolved outbound edges, by ref name. `refs` is what the author
    # wrote; this is what it resolves to once type defaults (site
    # fallback, family defaults) are applied. Core inverts it into
    # refsIn alongside raw refs, so the inverse index is complete
    # even when the edge was inherited rather than written.
    relations ? _name: _config: _topConfig: {},
    attrs ? _name: _config: _topConfig: {},
    verbs ? _name: _config: _topConfig: {},
    assertions ? _name: _config: _topConfig: [],
  }:
    let
      typeName = name;
      mod = {
        options.${typeName} = mkOption {
          type = types.nullOr (types.submodule { inherit options; });
          default = null;
        };
      };
    in {
      config.types.${typeName} = { inherit description; };

      options.entities = mkOption {
        type = types.attrsWith {
          lazy = true;
          placeholder = "id";
          elemType = types.submodule ({ config, name, ... }: {
            imports = [ mod ];

            config = mkIf (config.${typeName} != null) {
              type = typeName;
              attrs = attrs name config topConfig;
              relations = relations name config topConfig;
              verbs = verbs name config topConfig;
              assertions = assertions name config topConfig;
            };
          });
        };
      };
    };

  # Extend an existing type with more options/attrs/assertions.
  #
  # The module system merges a nested option declaration into an existing
  # submodule option, so an extension contributes `options.<type>.<field>`
  # alongside the base type's `options.<type> = mkOption { … }`. The base
  # type's module and this one must have the same submodule shape (same
  # `functionArgs`) for the merge to take; both use `{ config, name, … }`.
  # The type itself is registered by the base, so this does not touch
  # `config.types`.
  mkTypeExtend = {
    name,
    topConfig ? {},
    options ? {},
    attrs ? _name: _config: _topConfig: {},
    relations ? _name: _config: _topConfig: {},
    verbs ? _name: _config: _topConfig: {},
    assertions ? _name: _config: _topConfig: [],
  }:
    let
      typeName = name;
    in {
      options.entities = mkOption {
        type = types.attrsWith {
          lazy = true;
          placeholder = "id";
          elemType = types.submodule ({ config, name, ... }: {
            options.${typeName} = mkOption {
              type = types.nullOr (types.submodule { inherit options; });
            };

            config = mkIf (config.${typeName} != null) {
              attrs = attrs name config topConfig;
              relations = relations name config topConfig;
              verbs = verbs name config topConfig;
              assertions = assertions name config topConfig;
            };
          });
        };
      };
    };

  # A facet aspect: contributes *top-level* options on the entity (not a
  # type bag). It registers nothing and derives no `type`; presence is
  # whatever the caller's `attrs` gate on. This is how a cross-cutting
  # concern (routing, monitoring, …) attaches to any entity without
  # being nested under a kind.
  mkAspect = {
    topConfig ? {},
    options ? {},
    relations ? _name: _config: _topConfig: {},
    attrs ? _name: _config: _topConfig: {},
    assertions ? _name: _config: _topConfig: [],
  }: {
    options.entities = mkOption {
      type = types.attrsWith {
        lazy = true;
        placeholder = "id";
        elemType = types.submodule ({ config, name, ... }: {
          inherit options;

          config = {
            relations = relations name config topConfig;
            attrs = attrs name config topConfig;
            assertions = assertions name config topConfig;
          };
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
  refType = types.either types.str (types.submodule {
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
  });

  # The far entity's name, whichever spelling the ref used.
  refTarget = ref: if builtins.isString ref then ref else ref.target;

  # Rich form for either spelling — for consumers that want one shape.
  refNorm = ref:
    if builtins.isString ref
    then { target = ref; port = null; nic = null; }
    else ref;

  # ── Querying ────────────────────────────────────────────────────────

  ofType = typeName: entities:
    lib.filterAttrs (_: e: e.type == typeName) entities;

  tagged = tag: entities:
    lib.filterAttrs (_: e: builtins.elem tag e.tags) entities;

  withAttr = attrName: entities:
    lib.filterAttrs (_: e: e.attrs ? ${attrName} && e.attrs.${attrName} != null) entities;

  # A capability is just an attrs key whose schema is its contract; these
  # are the query spelling. `withAspect "ssh"` is "everything sshable".
  withAspect = withAttr;
  hasAspect = attrName: e: e.attrs ? ${attrName} && e.attrs.${attrName} != null;

  collectAttr = attrName: entities:
    lib.mapAttrs (_: e: e.attrs.${attrName}) (withAttr attrName entities);

  refsOf = entity: allEntities:
    lib.mapAttrs (_: ref: allEntities.${refTarget ref}) entity.refs;

  referencedBy = targetName: entities:
    lib.filterAttrs (_: e:
      builtins.any (ref: refTarget ref == targetName) (builtins.attrValues e.refs)
    ) entities;

  withVerb = verbName: entities:
    lib.filterAttrs (_: e: e.verbs ? ${verbName}) entities;

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
  # attrset minus `topConfig` (which the interceptor injects):
  #
  #   {
  #     egregoreType = { lib, egregorLib, config, ... }: {
  #       name = "site";
  #       description = "...";
  #       options = { domain = lib.mkOption { ... }; ... };
  #       attrs = name: entity: top: { ... };
  #     };
  #   }
  #
  # A plain attrset is also accepted for types that don't need lib in
  # their attrs/verbs/assertions bodies.
  interceptors.egregoreType = {
    enter = bundle:
      if !(bundle.value ? egregoreType) then bundle
      else
        let
          etype = bundle.value.egregoreType;
          typeModule = moduleArgs:
            let
              inherit (moduleArgs) egregorLib config;
              resolved = if builtins.isFunction etype then etype moduleArgs else etype;
            in
              if resolved ? extends
              then egregorLib.mkTypeExtend
                ((builtins.removeAttrs resolved [ "extends" ]) // {
                  name = resolved.extends;
                  topConfig = config;
                })
              else egregorLib.mkType (resolved // { topConfig = config; });
        in bundle // {
          value = (builtins.removeAttrs bundle.value ["egregoreType"]) // {
            imports = (bundle.value.imports or []) ++ [ typeModule ];
          };
        };
  };

  # An `egregoreAspect` spec field: a facet contributing top-level entity
  # options (see `mkAspect`). Same shape as a type spec, but registers
  # nothing and derives no `type`.
  #
  #   { egregoreAspect = { lib, config, ... }: {
  #       options = { vpn = lib.mkOption { ... }; };
  #       attrs = name: entity: top: { ... };
  #   }; }
  interceptors.egregoreAspect = {
    enter = bundle:
      if !(bundle.value ? egregoreAspect) then bundle
      else
        let
          etype = bundle.value.egregoreAspect;
          aspectModule = moduleArgs:
            let
              inherit (moduleArgs) egregorLib config;
              resolved = if builtins.isFunction etype then etype moduleArgs else etype;
            in egregorLib.mkAspect (resolved // { topConfig = config; });
        in bundle // {
          value = (builtins.removeAttrs bundle.value ["egregoreAspect"]) // {
            imports = (bundle.value.imports or []) ++ [ aspectModule ];
          };
        };
  };
}
