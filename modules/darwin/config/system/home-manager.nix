{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.system.home-manager;
in {
  options = {
    psyclyx.system.home-manager = {
      enable = lib.mkEnableOption "home-manager config";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager = {
      sharedModules = [config.psyclyx.darwin.deps.nixclyx.homeManagerModules.default];
      useGlobalPkgs = true;
      useUserPackages = true;
    };
  };
}
