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
  options.psyclyx.services.mako = {
    enable = lib.mkEnableOption "mako";
  };
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [ notify-desktop ];
    services.mako = {
      enable = true;
      settings = {
        actions = true;
        anchor = "top-right";
        borderRadius = 6;
        borderSize = 4;
        defaultTimeout = 10000;
      };
    };
  };
}
