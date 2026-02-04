{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.psyclyx.nixos.services.openrgb;
in {
  options = {
    psyclyx.nixos.services.openrgb = {
      enable = lib.mkEnableOption "OpenRGB";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.i2c-tools
      pkgs.openrgb-with-all-plugins
    ];

    services.hardware.openrgb.enable = true;
  };
}
