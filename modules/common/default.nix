{ lib, ... }:
let
  importWithArgs = modulePath: importArgs: {
    imports = [ (lib.modules.importApply modulePath importArgs) ];
  };

  groups = {
    common.moduleGroup = "common";
    darwin.moduleGroup = "darwin";
    nixos.moduleGroup = "nixos";
  };
in
builtins.mapAttrs (_: importWithArgs ./config) groups
