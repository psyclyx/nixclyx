{pkgs}:
builtins.mapAttrs (_: x: pkgs.callPackage x {}) {
  print256colors = ./print256colors.nix;
  river = ./river;
  tidepool = ./tidepool;
  "base24-gen" = ./base24-gen;
  shoal = ./shoal;
  ilo4-console = ./ilo4-console.nix;
  ssacli = ./ssacli.nix;
  upscale-image = ./upscale-image;
}
