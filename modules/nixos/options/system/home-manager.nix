{
  config,
  lib,
  nixclyx,
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
      sharedModules = [
        (nixclyx.modules.home.options {inherit nixclyx;})
        nixclyx.modules.home.config
      ];
    };
  };
}
