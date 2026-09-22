# iLO platform — option schema (generic, egregore-unaware).
#
# The desired BMC state as data, plus the address it applies to. A fleet
# projection derives the state from the host's boot intent; the render
# module turns it into the spec JSON and the plan/apply/power scripts.
{ lib, ... }:
let
  inherit (lib) mkOption types;
in {
  options.system.build = mkOption { type = types.attrsOf types.package; default = { }; };
  options.ilo = mkOption {
    default = { };
    type = types.submodule {
      options = {
        model = mkOption { type = types.str; default = ""; };
        address = mkOption { type = types.str; default = ""; };
        # The desired-state document, in `ilo-config`'s shape. Kept
        # open: the BMC's settable surface is large and the tool owns
        # the schema, so the platform carries it as data rather than
        # re-declaring every Redfish attribute.
        spec = mkOption { type = types.anything; default = { }; };
      };
    };
  };
}
