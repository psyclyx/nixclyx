{pkgs}:
builtins.mapAttrs (_: x: pkgs.callPackage x {}) {
  print256colors = ./print256colors.nix;
  ensure-key = ./ensure-key.nix;
  sign-key = ./sign-key.nix;
  pki = ./pki;
  ssacli = ./ssacli.nix;
  upscale-image = ./upscale-image;
}
