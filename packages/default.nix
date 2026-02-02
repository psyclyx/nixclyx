{pkgs}:
builtins.mapAttrs (_: x: pkgs.callPackage x {}) {
  print256colors = ./print256colors.nix;
  ensure-key = ./ensure-key.nix;
  sign-key = ./sign-key.nix;
  provision-host = ./provision-host.nix;
  pki-manage = ./pki-manage.nix;
  ssacli = ./ssacli.nix;
  upscale-image = ./upscale-image;
}
