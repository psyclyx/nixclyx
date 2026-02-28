{pkgs}:
builtins.mapAttrs (_: x: pkgs.callPackage x {}) {
  print256colors = ./print256colors.nix;
  ensure-key = ./ensure-key.nix;
  sign-key = ./sign-key.nix;
  pki = ./pki;
  river = ./river;
  tidepool = ./tidepool;
  ssacli = ./ssacli.nix;
  upscale-image = ./upscale-image;
}
