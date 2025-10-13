{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.psyclyx.services.mako;
in
{
  options = {
    psyclyx.services.mako = {
      enable = lib.mkEnableOption "Mako notification daemon";
    };
  };
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [ notify-desktop ];
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
