# Egregore — typed extensible entity registry.
#
# A framework for declaring typed entities with extensible schemas
# and queryable aspects. The topology, deployment,
# monitoring, and diagrams of your infrastructure (or anything else)
# emerge as projections over the same underlying data.
#
# Usage:
#
#   let
#     egregore = import ./egregore { inherit lib; };
#     infra = egregore.eval {
#       modules = [
#         ./types/routeros.nix
#         ./types/ilo.nix
#         ./my-entities.nix
#       ];
#     };
#   in
#     infra.entities          # all entities, fully resolved
#     infra.entities.foo.address
#
{ lib }:
let
  elib = import ./lib.nix { inherit lib; };
in {
  lib = elib;

  eval = { modules ? [] }:
    let
      result = lib.evalModules {
        modules = [ ./core.nix ] ++ modules;
        specialArgs = { egregorLib = elib; };
      };
      cfg = result.config;
      failed = builtins.filter (a: !a.assertion) cfg.assertions;
    in
      if failed != []
      then throw (
        "egregore: validation failed:\n"
        + lib.concatMapStringsSep "\n" (a: "  - ${a.message}") failed
      )
      else removeAttrs cfg [ "assertions" "_module" ];
}
