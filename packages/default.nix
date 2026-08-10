{pkgs}:
let
  # Internal producers (river, set-output-icc, tidepool, base24-gen, shoal)
  # are provided by their own overlays now; only nixclyx's own packages live
  # here. Producers are aliased back under pkgs.psyclyx.* in ../overlay.nix.
  packages = builtins.mapAttrs (_: x: pkgs.callPackage x {}) {
    print256colors = ./print256colors.nix;
    spork = ./spork.nix;
    ilo4-console = ./ilo4-console.nix;
    nvf = ./nvf.nix;
    ssacli = ./ssacli.nix;
    upscale-image = ./upscale-image;
    sodola-config = ./sodola-config;
    swos-config = ./swos-config;
    routeros-config = ./routeros-config;
  };
in
  packages // {
    ilo = pkgs.callPackage ./ilo.nix {
      inherit (packages) ilo4-console;
    };
    janet-lsp = pkgs.callPackage ./janet-lsp.nix {
      inherit (packages) spork;
    };
    # base24-gen comes from its producer overlay (in pkgs), resolved by callPackage.
    regenerate-palettes = pkgs.callPackage ./regenerate-palettes.nix { };
    egregore = pkgs.callPackage ./egregore.nix {
      inherit (packages) sodola-config swos-config routeros-config;
    };
  }
