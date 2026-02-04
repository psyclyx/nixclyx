{
  config,
  lib,
  nixclyx,
  ...
}: let
  cfg = config.psyclyx.darwin.system.home-manager;
in {
  options.psyclyx.darwin.system.home-manager = {
    enable = lib.mkEnableOption "home-manager config";
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
