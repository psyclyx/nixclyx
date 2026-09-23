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
    commit-confirm = ./commit-confirm;
    pi = ./pi-agent;
  };

  # Platform renderers live with their platform library (`lib/platform`).
  platform = {
    sodola-config = pkgs.callPackage ../lib/platform/sodola/render { };
    swos-config = pkgs.callPackage ../lib/platform/swos/render { };
    routeros-config = pkgs.callPackage ../lib/platform/routeros/render { };
    ilo-config = pkgs.callPackage ../lib/platform/ilo/render { };
  };
in
  packages
  // platform
  // {
    # The iLO CLI (Redfish/KVM) — the replacement for the old imperative
    # tool dropped in "chore: drop the old imperative ilo tool". Keeps
    # pkgs.psyclyx.ilo resolving for the ipmi and workstation modules.
    ilo = pkgs.callPackage ../lib/platform/ilo/cli {
      inherit (packages) ilo4-console;
      inherit (platform) ilo-config;
    };
    janet-lsp = pkgs.callPackage ./janet-lsp.nix {
      inherit (packages) spork;
    };
    # base24-gen comes from its producer overlay (in pkgs), resolved by callPackage.
    regenerate-palettes = pkgs.callPackage ./regenerate-palettes.nix { };
    egregore = pkgs.callPackage ./egregore.nix {
      inherit (platform) sodola-config swos-config routeros-config ilo-config;
    };
  }
