{
  nixclyx,
  pkgs,
  ...
}:
nixclyx.lib.callSupportedPackages pkgs {
  print256colors = ./print256colors.nix;
  ensure-key = ./ensure-key.nix;
  sign-key = ./sign-key.nix;
  provision-host = ./provision-host.nix;
  ssacli = ./ssacli.nix;
  upscale-image = ./upscale-image;
}
