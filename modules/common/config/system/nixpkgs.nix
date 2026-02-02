{moduleGroup ? "common"}: {
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.${moduleGroup}.system.nixpkgs;
in {
  options = {
    psyclyx.${moduleGroup}.system.nixpkgs.enable = lib.mkEnableOption "nixpkgs config (unfree, etc)";
  };

  config = lib.mkMerge [
    {nixpkgs.overlays = [config.psyclyx.common.deps.nixclyx.overlays.default];}

    (lib.mkIf cfg.enable {
      nixpkgs = {
        config = {
          allowUnfree = true;
          nvidia.acceptLicense = true;
        };
      };
    })
  ];
}
