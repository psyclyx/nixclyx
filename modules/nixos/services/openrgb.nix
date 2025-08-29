{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.services.openrgb;
in
{
  options = {
    psyclyx.services.openrgb.enable = lib.mkEnableOption "OpenRGB";
  };
  config = lib.mkIf cfg.enable {
    services.hardware.openrgb.enable = true;
    environment.systemPackages = with pkgs; [
      i2c-tools
      openrgb-with-all-plugins
    ];
  };
}
