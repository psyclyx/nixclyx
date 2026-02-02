{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.nixos.system.home-manager;
in {
  options = {
    psyclyx.nixos.system.home-manager = {
      enable = lib.mkEnableOption "home-manager config";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
    };
  };
}
