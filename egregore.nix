# Egregore entry point — delegates to configs/egregore/.
#
# The CLI evaluates this file. Returns: { lib, modules }
let
  cfg = import ./configs/egregore;
in {
  lib = cfg.egregoreLib;
  modules = cfg.modules;
}
