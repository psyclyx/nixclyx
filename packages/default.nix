{ nixclyx, pkgs, ... }:
nixclyx.lib.callSupportedPackages pkgs {
  intelmas = ./intelmas.nix;
  print256colors = ./print256colors.nix;
  ssacli = ./ssacli.nix;
  upscale-image = ./upscale-image;
}
