# Core module — defines the fundamental schema: entities, types, assertions.
#
# Entities are records in an extensible registry. Each entity has:
#   name  — its id (the key it is registered under)
#   tags  — freeform labels for filtering
#   refs  — named references to other entities (validated)
#   edges — refs in normalized shape ({ target; port; nic; })
#   verbs — available operations (set by type modules)
#
# No field stores the type (model §4): the type of an entity is the name
# of the kind that is present — a kind is an option value that is not
# null (`e.host != null` is "this is a host"). Type modules extend the
# entity submodule to add kind options, derived keys, and verbs. The
# module system merges everything — each entity instance sees all type
# modules' options, but only the present kind's derived keys/verbs are
# active (via mkIf).
#
# A ref value is either a bare entity name or `{ target; port; nic; }`
# naming the attachment point on the far side. `edges` carries the
# rich shape for both spellings; refs itself is left as written, so a
# reader that just wants the name reads it the same way it always did.
#
# Every entity also gets an automatic refsIn — the inverse of refs and
# relations. If `foo.refs.bar = "baz"`, then `baz.refsIn.bar` contains
# `"foo"`. Type modules may also state a resolved relation with the same
# name, so an edge inherited from a default (a network's gateway from its
# site) is inverted too. Lets target entities answer "who refs me?"
# without scattering filter queries across type modules.
#
{ config, lib, egregorLib, ... }:
let
  inherit (lib) mkOption types;
  inherit (egregorLib) refType refTarget refNorm edgeType;
in {
  options = {
    assertions = mkOption {
      type = types.listOf types.anything;
      default = [];
      internal = true;
      description = "Validation assertions. Checked at eval time.";
    };

    types = mkOption {
      description = ''
        Registered entity kinds. Documentation/registration only — the
        kind options and this registry come as a pair from mkType, and
        the type of an entity is the name of the kind that is present.
      '';
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
      type = types.attrsWith {
        lazy = true;
        placeholder = "id";
        # The entity is a `submoduleWith` whose aspect modules all see
        # the top graph as the `egregore` module argument (model §9).
        # The combined `options.entities` declaration across core,
        # mkType, mkTypeExtend and mkAspect merges into exactly
        # `submoduleWith { modules = aspects; specialArgs = { egregore =
        # topConfig; }; }` — this declaration owns the specialArgs (the
        # module system rejects two declarations carrying the same
        # specialArgs name; the others contribute `types.submodule`
        # modules with empty specialArgs).
        elemType = types.submoduleWith {
          shorthandOnlyDefinesConfig = true;
          specialArgs = { egregore = config; };
          modules = [ ({ name, config, egregore, ... }: {
        options = {
          tags = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Freeform tags for filtering and grouping.";
          };

          refs = mkOption {
            type = types.attrsOf refType;
            default = {};
            description = ''
              Named references to other entities — the graph's edges.

              A value is either an entity name, or an attrset naming the
              entity plus the attachment point on the far side
              (`{ target; port; nic; }`). Both spellings mean the same
              edge; `edges` gives the rich shape for either.

              Validated: every target must exist in the registry.
            '';
          };

          name = mkOption {
            type = types.str;
            description = "The entity's id — the key it is registered under.";
          };

          edges = mkOption {
            type = types.attrsOf edgeType;
            default = {};
            description = ''
              This entity's own refs in rich form, so a consumer reading
              an edge's attachment point never has to branch on the
              spelling. `refs.<n>` itself is left exactly as written —
              the plain form still reads back as a bare name.
            '';
          };

          relations = mkOption {
            type = types.attrsOf (types.nullOr types.str);
            default = {};
            internal = true;
            description = ''
              Resolved outbound edges, keyed by ref name. Type modules
              state an edge here in the form it actually has — after
              site-level fallback and family defaults — so its inverse is
              queryable. `refs` stays the author's declaration; this is
              the graph's actual edge. Null means "no resolved edge".
            '';
          };

          refsIn = mkOption {
            type = types.attrsOf (types.listOf types.str);
            default = {};
            internal = true;
            description = ''
              Inverse index: for each ref name, the entities that refer to
              this one. Computed from every entity's `refs` and `relations`.
              A top-level option, not an aspect, so a type's own derived
              keys can read it without depending on the keys it is
              computing.
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
                defaults = mkOption {
                  type = types.listOf types.str;
                  default = [];
                  description = "Default arguments used when none are given on the command line.";
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
        config.name = name;

        # This entity's own refs in rich form.
        config.edges = lib.mapAttrs (_: refNorm) config.refs;

        # Inverse index: for each (src, refName) whose declared ref *or*
        # resolved relation targets this entity, append srcName to
        # config.refsIn.refName. Both inputs are plain data — not derived
        # keys of this entity — so there is no cycle with the derive
        # hooks.
        #
        # Covering resolved relations is what makes an inherited edge
        # queryable: a network whose gateway comes from its site never
        # writes `refs.gateway`, but still shows up in the site router's
        # refsIn.gateway.
        config.refsIn = let
          add = acc: refName: srcName:
            acc // { ${refName} = lib.unique ((acc.${refName} or []) ++ [srcName]); };
        in lib.foldlAttrs (acc: srcName: src:
          let
            afterRefs = lib.foldlAttrs (a: refName: ref:
              if refTarget ref == name then add a refName srcName else a
            ) acc src.refs;
          in lib.foldlAttrs (a: refName: target:
            if target != null && target == name then add a refName srcName else a
          ) afterRefs (src.relations or {})
        ) {} egregore.entities;
          }) ];
        };
      };
      default = {};
    };
  };

  config.assertions =
    # Every entity must present exactly one registered kind. The type of
    # an entity is the name of the kind that is present (model §4); no
    # field stores it. A present kind is an option value that is not
    # null, among the registered kind names — every present kind is
    # registered by construction (the kind options and the registry come
    # as a pair), so what this catches is "no kind present" (the old
    # unregistered-type case) and "several kinds present" (which cannot
    # name one type).
    lib.mapAttrsToList (name: entity:
      let
        registered = builtins.attrNames config.types;
        present = builtins.filter
          (k: (entity.${k} or null) != null)
          registered;
      in {
        assertion = builtins.length present == 1;
        message =
          if present == []
          then "entity '${name}' has unregistered type: no registered kind is present (registered kinds: ${lib.concatStringsSep ", " registered})"
          else "entity '${name}' has several present kinds (${lib.concatStringsSep ", " present}) — the type of an entity is the name of the kind that is present";
      }) config.entities

    # All refs must resolve to existing entities.
    ++ lib.concatLists (lib.mapAttrsToList (name: entity:
      lib.mapAttrsToList (refName: ref: let target = refTarget ref; in {
        assertion = config.entities ? ${target};
        message = "entity '${name}' ref '${refName}' → '${target}' does not exist";
      }) entity.refs
    ) config.entities)

    # Propagate per-entity assertions.
    ++ lib.concatLists (lib.mapAttrsToList (_: e: e.assertions) config.entities);
}
