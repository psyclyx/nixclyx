{ nixclyx, pkgs, ... }:
nixclyx.lib.callSupportedPackages pkgs {
  disclyx = ./disclyx;
  intelmas = ./intelmas.nix;
  print256colors = ./print256colors.nix;
  ssacli = ./ssacli.nix;
  upscale-image = ./upscale-image;
}
