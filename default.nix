let
  # Phase 1: Core — standalone values with no module dependencies.
  sources = import ./npins;
  loadFlake = import ./loadFlake.nix;
  lib = import ./lib;
  assets = import ./assets;
  overlay = import ./overlay.nix;
  packages = import ./packages;

  core = {
    inherit sources loadFlake lib assets overlay packages;
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
  };

  # Phase 3: Consumers — depend on modules.
  evalConfig = import (sources.nixpkgs + "/nixos/lib/eval-config.nix");

  mkHost = name:
    evalConfig {
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

  # The full nixclyx attrset. Modules see this via _module.args (lazy).
  # hive/configurations/darwinConfigurations are top-level consumers only —
  # no module spec should reference them.
  nixclyx = core // {
    inherit modules hive configurations darwinConfigurations;
    overlays.default = overlay;
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
  nixclyx
