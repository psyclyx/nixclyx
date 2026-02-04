{
  config,
  lib,
  nixclyx,
  ...
}: let
  cfg = config.psyclyx.common.system.nixpkgs;
in {
  options = {
    psyclyx.common.system.nixpkgs.enable = lib.mkEnableOption "nixpkgs config (unfree, etc)";
  };

  config = lib.mkMerge [
    {nixpkgs.overlays = [nixclyx.overlays.default];}

    (lib.mkIf cfg.enable {
      nixpkgs.config = {
        allowUnfree = true;
        nvidia.acceptLicense = true;
      };
    })
  ];
}
