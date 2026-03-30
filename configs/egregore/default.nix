# Psyclyx fleet — egregore entry point.
#
# Assembles the framework, type modules, and fleet data into a single
# egregore spec. The CLI and NixOS topology module evaluate this.
let
  mods = import ../../modules/egregore;
  lib = import <nixpkgs/lib>;
  fs = import ../../lib/fs.nix;

  # Compile config specs into egregore modules, same pattern as NixOS.
  mkEgregoreModule = spec: moduleArgs @ { config, lib, ... }: let
    eval = x:
      if builtins.isFunction x
      then x moduleArgs
      else x;
    gate = spec.gate or "always";
  in {
    imports = spec.imports or [];
    options = eval (spec.options or {});
    config = let
      body = eval (spec.config or null);
    in
      if body == null then {}
      else if gate == "always" then body
      else body;
  };

  configSpecs = map builtins.import (fs.collectModules ./.);
in {
  inherit lib;
  egregoreLib = ../../egregore;

  modules =
    mods.types
    ++ mods.extensions
    ++ map mkEgregoreModule configSpecs;
}
