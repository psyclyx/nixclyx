let
  sources = import ./npins;
  loadFlake = import ./loadFlake.nix;
  lib = import ./lib;
  assets = import ./assets;
  overlay = import ./overlay.nix;
  packages = import ./packages;

  mkNixclyx = {...}: let
    modules = {
      nixos = import ./modules/nixos {inherit nixclyx;};
      darwin = import ./modules/darwin {inherit nixclyx;};
      home = import ./modules/home {inherit nixclyx;};
      common = import ./modules/common {inherit nixclyx;};
      nvf = import ./modules/nvf {inherit nixclyx;};
    };

    evalConfig = import (sources.nixpkgs + "/nixos/lib/eval-config.nix");

    mkHost = name:
      evalConfig {
        system = "x86_64-linux";
        modules = [
          modules.nixos
          {config.psyclyx.nixos.host = name;}
        ];
      };

    hostEntries = builtins.readDir ./modules/nixos/hosts;
    hostNames =
      builtins.filter
      (n: hostEntries.${n} == "directory")
      (builtins.attrNames hostEntries);

    configurations = builtins.listToAttrs (map (name: {
        inherit name;
        value = mkHost name;
      })
      hostNames);

    darwinSystem = (loadFlake sources.nix-darwin).lib.darwinSystem;

    mkDarwinHost = name:
      darwinSystem {
        modules = [
          modules.darwin
          {config.psyclyx.darwin.host = name;}
        ];
      };

    darwinConfigurations = builtins.mapAttrs (name: _: mkDarwinHost name) {
      halo = {};
    };

    hive = import ./hive.nix {inherit nixclyx;};

    nixclyx = {
      inherit sources modules lib assets loadFlake;
      inherit configurations darwinConfigurations hive;
      overlays.default = overlay;
      keys = import ./data/keys.nix;
      packageGroups = import ./data/packageGroups.nix;
      docs = import ./docs {inherit nixclyx;};
      nvf = pkgs:
        ((import sources.nvf).lib.neovimConfiguration {
          inherit pkgs;
          modules = [
            modules.nvf
            {psyclyx.nixos.programs.nvf.enable = true;}
          ];
        }).neovim;
    };
  in
    nixclyx;

  # Default instance with functor for customization
  default =
    mkNixclyx {}
    // {
      __functor = self: mkNixclyx;
    };
in
  default
