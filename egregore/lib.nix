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
    entityModule ? null,
    attrs ? _name: _config: _topConfig: {},
    verbs ? _name: _config: _topConfig: {},
    assertions ? _name: _config: _topConfig: [],
  }:
    let
      typeName = name;
      mod =
        if entityModule != null then entityModule
        else if options != {} then {
          options.${typeName} = mkOption {
            type = types.submodule { inherit options; };
            default = {};
          };
        }
        else {};
    in {
      config.types.${typeName} = { inherit description; };

      options.entities = mkOption {
        type = types.attrsOf (types.submodule ({ config, name, ... }: {
          imports = [ mod ];

          config = mkIf (config.type == typeName) {
            attrs = attrs name config topConfig;
            verbs = verbs name config topConfig;
            assertions = assertions name config topConfig;
          };
        }));
      };
    };

  # ── Querying ────────────────────────────────────────────────────────

  ofType = typeName: entities:
    lib.filterAttrs (_: e: e.type == typeName) entities;

  tagged = tag: entities:
    lib.filterAttrs (_: e: builtins.elem tag e.tags) entities;

  withAttr = attrName: entities:
    lib.filterAttrs (_: e: e.attrs ? ${attrName} && e.attrs.${attrName} != null) entities;

  collectAttr = attrName: entities:
    lib.mapAttrs (_: e: e.attrs.${attrName}) (withAttr attrName entities);

  refsOf = entity: allEntities:
    lib.mapAttrs (_: target: allEntities.${target}) entity.refs;

  referencedBy = targetName: entities:
    lib.filterAttrs (_: e:
      builtins.any (t: t == targetName) (builtins.attrValues e.refs)
    ) entities;

  withVerb = verbName: entities:
    lib.filterAttrs (_: e: e.verbs ? ${verbName}) entities;
}
