# Egregore entry point — delegates to configs/egregore/.
#
# Returns: { lib, root, mkModule }
#
# `root` is a single egregore module whose `imports` reach every
# nixclyx-shipped type/extension/config spec. Out-of-tree consumers
# compose by writing their own root with
# `imports = [nixclyx.root ...local specs...]`.
#
# `mkModule` is the shared spec compiler from `nixclyx/lib/modules.nix`,
# re-exported here so consumers can compile their own config specs the
# same way nixclyx does.
let
  cfg = import ./configs/egregore;
in {
  lib = cfg.egregoreLib;
  inherit (cfg) root mkModule;
}
