{nixclyx, pkgs, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "services" "openrgb"];
  description = "OpenRGB";
  config = _: {
    environment.systemPackages = [
      pkgs.i2c-tools
      pkgs.openrgb-with-all-plugins
    ];

    services.hardware.openrgb.enable = true;
  };
} args
