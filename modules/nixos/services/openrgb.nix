{
  path = ["psyclyx" "nixos" "services" "openrgb"];
  description = "OpenRGB";
  config = {pkgs, ...}: {
    environment.systemPackages = [
      pkgs.i2c-tools
      pkgs.openrgb-with-all-plugins
    ];

    services.hardware.openrgb.enable = true;
  };
}
