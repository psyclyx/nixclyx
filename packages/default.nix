{ nixclyx, pkgs, ... }:
nixclyx.lib.callSupportedPackages pkgs {
  print256colors = ./print256colors.nix;
  ssacli = ./ssacli.nix;
  upscale-image = ./upscale-image;
}
