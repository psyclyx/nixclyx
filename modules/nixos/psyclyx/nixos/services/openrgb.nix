{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.psyclyx.nixos.services.openrgb;
in
{
  options = {
    psyclyx.nixos.services.openrgb = {
      enable = mkEnableOption "OpenRGB";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.i2c-tools
      pkgs.openrgb-with-all-plugins
    ];

    services.hardware.openrgb.enable = true;
  };
}
