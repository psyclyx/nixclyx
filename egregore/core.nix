# Core module — defines the fundamental schema: entities, types, assertions.
#
# Entities are typed records in an extensible registry. Each entity has:
#   type  — which registered type it is (determines schema, attrs, verbs)
#   tags  — freeform labels for filtering
#   refs  — named references to other entities (validated)
#   attrs — computed queryable properties (set by type modules)
#   verbs — available operations (set by type modules)
#
# Type modules extend the entity submodule to add type-specific options,
# attrs, and verbs. The module system merges everything — each entity
# instance sees all type modules' options, but only the matching type's
# attrs/verbs are active (via mkIf).
#
{ config, lib, ... }:
let
  inherit (lib) mkOption types;
in {
  options = {
    assertions = mkOption {
      type = types.listOf types.anything;
      default = [];
      internal = true;
      description = "Validation assertions. Checked at eval time.";
    };

    types = mkOption {
      description = "Registered entity types.";
      type = types.attrsOf (types.submodule {
        options.description = mkOption {
          type = types.str;
          default = "";
        };
      });
      default = {};
    };

    entities = mkOption {
      description = "Entity registry.";
      type = types.attrsOf (types.submodule ({ name, config, ... }: {
        options = {
          type = mkOption {
            type = types.str;
            description = "Entity type — must match a registered type.";
          };

          tags = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Freeform tags for filtering and grouping.";
          };

          refs = mkOption {
            type = types.attrsOf types.str;
            default = {};
            description = ''
              Named references to other entities. Values are entity names.
              Validated: every target must exist in the registry.
            '';
          };

          attrs = mkOption {
            type = types.attrsOf types.anything;
            default = {};
            description = ''
              Queryable properties — set by type modules, read by projections.
              Open vocabulary: types declare what they answer.
            '';
          };

          verbs = mkOption {
            type = types.attrsOf (types.submodule {
              options = {
                description = mkOption {
                  type = types.str;
                  default = "";
                };
                pure = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Pure verbs produce a value. Impure verbs produce a shell script.";
                };
                impl = mkOption {
                  type = types.anything;
                  description = "The verb's implementation — a value (pure) or shell script string (impure).";
                };
              };
            });
            default = {};
            description = ''
              Available operations — set by type modules.
              Open vocabulary: types declare what they can do.
            '';
          };

          assertions = mkOption {
            type = types.listOf types.anything;
            default = [];
            internal = true;
            description = "Per-entity assertions, propagated to top level.";
          };
        };

        # Every entity knows its own name.
        config.attrs.name = name;
      }));
      default = {};
    };
  };

  config.assertions =
    # Every entity's type must be registered.
    lib.mapAttrsToList (name: entity: {
      assertion = config.types ? ${entity.type};
      message = "entity '${name}' has unregistered type '${entity.type}'";
    }) config.entities

    # All refs must resolve to existing entities.
    ++ lib.concatLists (lib.mapAttrsToList (name: entity:
      lib.mapAttrsToList (refName: target: {
        assertion = config.entities ? ${target};
        message = "entity '${name}' ref '${refName}' → '${target}' does not exist";
      }) entity.refs
    ) config.entities)

    # Propagate per-entity assertions.
    ++ lib.concatLists (lib.mapAttrsToList (_: e: e.assertions) config.entities);
}
