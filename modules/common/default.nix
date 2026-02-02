deps: let
  importWithArgs = modulePath: importArgs: {lib, ...}: {
    imports = [
      (lib.modules.importApply modulePath importArgs)
      {
        options.psyclyx.common.deps = lib.mkOption {
          type = lib.types.attrsOf lib.types.unspecified;
          default = {};
        };
        config.psyclyx.common = {inherit deps;};
      }
    ];
  };

  groups = {
    common.moduleGroup = "common";
    darwin.moduleGroup = "darwin";
    nixos.moduleGroup = "nixos";
  };
in
  builtins.mapAttrs (_: importWithArgs ./config) groups
