# Psyclyx fleet — egregore entry point.
#
# Assembles the framework, type modules, and fleet data into a single
# egregore spec. The CLI and NixOS topology module evaluate this.
let
  mods = import ../../modules/egregore;
  lib = import <nixpkgs/lib>;
  fs = import ../../lib/fs.nix;
  libModules = import ../../lib/modules.nix;

  configSpecs = map builtins.import (fs.collectModules ./.);

  # Single root spec: every nixclyx-shipped module reachable via its
  # `imports`. Out-of-tree consumers compose by writing their own root
  # spec with `imports = [nixclyx.root ...local specs...]`.
  root = {
    imports =
      mods.types
      ++ mods.extensions
      ++ map libModules.mkModule configSpecs;
  };
in {
  inherit lib root;
  inherit (libModules) mkModule;
  egregoreLib = ../../egregore;
}
