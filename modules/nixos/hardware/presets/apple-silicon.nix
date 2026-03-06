{
  path = ["psyclyx" "nixos" "hardware" "presets" "apple-silicon"];
  description = "Apple Silicon (Asahi Linux)";
  config = {lib, ...}: {
    nixpkgs.hostPlatform = "aarch64-linux";

    hardware.asahi.enable = true;

    boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

    boot.extraModprobeConfig = ''
      options hid_apple iso_layout=0
    '';

    hardware.apple.touchBar = {
      enable = true;
    };
  };
}
