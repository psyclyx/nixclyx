{
  path = ["psyclyx" "nixos" "hardware" "presets" "apple-silicon"];
  description = "Apple Silicon (Asahi Linux)";
  config = {
    lib,
    options,
    ...
  }:
    lib.mkMerge [
      {
        nixpkgs.hostPlatform = "aarch64-linux";

        boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

        boot.extraModprobeConfig = ''
          options hid_apple iso_layout=0
        '';
      }

      (lib.optionalAttrs (options ? hardware && options.hardware ? asahi) {
        hardware.asahi.enable = true;
      })

      (lib.optionalAttrs (options ? hardware && options.hardware ? apple) {
        hardware.apple.touchBar.enable = true;
      })
    ];
}
