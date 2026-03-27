let
  # Phase 1: Core — standalone values with no module dependencies.
  sources = import ./npins;
  loadFlake = import ./loadFlake.nix;
  lib = import ./lib;
  overlay = import ./overlay.nix;
  packages = import ./packages;

  core = {
    inherit sources loadFlake lib overlay packages;
    assets = ./assets;
    keys = import ./data/keys.nix;
    packageGroups = import ./data/packageGroups.nix;
  };

  # Phase 2: Modules — import-time uses core + sibling modules;
  # eval-time specs receive the full nixclyx via _module.args.
  modules = {
    home = import ./modules/home {inherit nixclyx;};
    common = import ./modules/common {inherit nixclyx;};
    nvf = import ./modules/nvf {inherit nixclyx;};
    nixos = import ./modules/nixos {inherit nixclyx;};
    darwin = import ./modules/darwin {inherit nixclyx;};
    nix-on-droid = import ./modules/nix-on-droid {inherit nixclyx;};
  };

  # Phase 3: Consumers — depend on modules.
  evalConfig = import (sources.nixpkgs + "/nixos/lib/eval-config.nix");

  hostEntries = builtins.readDir ./hosts/nixos;
  hostNames =
    builtins.filter
    (n: hostEntries.${n} == "directory")
    (builtins.attrNames hostEntries);

  mkHost = name:
    evalConfig {
      modules = [
        modules.nixos
        (./hosts/nixos + "/${name}")
      ];
    };

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

  nixOnDroidLib = (loadFlake sources.nix-on-droid).lib;

  mkDroidHost = name:
    nixOnDroidLib.nixOnDroidConfiguration {
      pkgs = import sources.nixpkgs {system = "aarch64-linux";};
      home-manager-path = sources.home-manager.outPath;
      modules = [
        modules.nix-on-droid
        {config.psyclyx.droid.host = name;}
      ];
    };

  nixOnDroidConfigurations = builtins.mapAttrs (name: _: mkDroidHost name) {
    phone = {};
  };

  hive = import ./hive.nix {inherit nixclyx;};

  # The full nixclyx attrset. Modules see this via _module.args (lazy).
  # hive/configurations/darwinConfigurations are top-level consumers only —
  # no module spec should reference them.
  nixclyx =
    core
    // {
      inherit modules hive configurations darwinConfigurations nixOnDroidConfigurations;
      hosts.nixos = builtins.listToAttrs (map (name: {
        inherit name;
        value = ./hosts/nixos + "/${name}";
      }) hostNames);
      overlays.default = overlay;
      docs = import ./docs {inherit nixclyx;};
      fleet-viz = pkgs:
        import ./packages/fleet-viz {
          inherit pkgs;
          fleetData = let fleet = import ./data/fleet; in fleet.topology // fleet;
        };
      nvf = pkgs:
        ((import sources.nvf).lib.neovimConfiguration {
          inherit pkgs;
          modules = [
            modules.nvf
            {psyclyx.nvf.roles.base.enable = true;}
          ];
        }).neovim;
    };
in
  nixclyx
