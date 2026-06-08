# Psyclyx fleet — egregore entry point.
#
# Assembles the framework, type modules, extensions, and fleet data
# into a single egregore root. The CLI and NixOS topology module
# evaluate this.
let
  mods = import ../../modules/egregore;
  lib = import <nixpkgs/lib>;
  fs = import ../../lib/fs.nix;
  libModules = import ../../lib/modules.nix;
  egregoreLib = import ../../egregore/lib.nix { inherit lib; };

  dataSpecs = map builtins.import (fs.collectModules ./.);

  # Egregore-flavored interceptor list: the egregoreType interceptor
  # handles type files, defaults handle the rest of the spec features
  # (path/enable/gate/variant). Type specs declare `egregoreType`;
  # extension and data specs use plain options/config like any module
  # spec.
  interceptors =
    [ egregoreLib.interceptors.egregoreType ]
    ++ libModules.defaultInterceptors;

  allSpecs = mods.typeSpecs ++ mods.extensionSpecs ++ dataSpecs;

  modules = libModules.compileSpecs { inherit interceptors; specs = allSpecs; };

  # Single root spec: every nixclyx-shipped module reachable via its
  # `imports`. Out-of-tree consumers compose by writing their own root
  # spec with `imports = [nixclyx.root ...local specs...]`.
  root = { imports = modules; };
in {
  inherit lib root;
  inherit (libModules) mkModule;
  egregoreLib = ../../egregore;
}
