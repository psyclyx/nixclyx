{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.psyclyx.home.services.mako;
in {
  options = {
    psyclyx.home.services.mako = {
      enable = mkEnableOption "Mako notification daemon";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [pkgs.notify-desktop];
    services.mako = {
      enable = true;
      settings = {
        actions = true;
        anchor = "top-right";
        border-radius = 6;
        border-size = 4;
        default-timeout = 10000;
      };
    };
  };
}
