{pkgs}:
let
  packages = builtins.mapAttrs (_: x: pkgs.callPackage x {}) {
    print256colors = ./print256colors.nix;
    river = ./river;
    spork = ./spork.nix;
    tidepool = ./tidepool;
    "base24-gen" = ./base24-gen;
    shoal = ./shoal;
    ilo4-console = ./ilo4-console.nix;
    nvf = ./nvf.nix;
    ssacli = ./ssacli.nix;
    egregore = ./egregore.nix;
    switch-deploy = ./switch-deploy.nix;
    upscale-image = ./upscale-image;
  };
in
  packages // {
    ilo = pkgs.callPackage ./ilo.nix {
      inherit (packages) ilo4-console;
    };
    janet-lsp = pkgs.callPackage ./janet-lsp.nix {
      inherit (packages) spork;
    };
    regenerate-palettes = pkgs.callPackage ./regenerate-palettes.nix {
      inherit (packages) base24-gen;
    };
  }
