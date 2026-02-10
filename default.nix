let
  sources = import ./npins;
  loadFlake = import ./loadFlake.nix;
  lib = import ./lib;
  assets = import ./assets;
  overlay = import ./overlay.nix;
  packages = import ./packages;

  mkNixclyx = {stateFile ? ./state.json}: let
    modules = {
      nixos = {
        options = import ./modules/nixos/options {inherit nixclyx;};
        config = import ./modules/nixos/config {inherit nixclyx;};
      };
      darwin = {
        options = import ./modules/darwin/options {inherit nixclyx;};
        config = import ./modules/darwin/config {inherit nixclyx;};
      };
      home = {
        options = import ./modules/home/options {inherit nixclyx;};
        config = import ./modules/home/config {inherit nixclyx;};
      };
      common = {
        options = import ./modules/common/options {inherit nixclyx;};
      };
      nvf = import ./modules/nvf {inherit nixclyx;};
    };

    evalConfig = import (sources.nixpkgs + "/nixos/lib/eval-config.nix");

    mkHost = name:
      evalConfig {
        system = "x86_64-linux";
        modules = [
          modules.nixos.options
          modules.nixos.config
          {config.psyclyx.nixos.host = name;}
        ];
      };

    hostEntries = builtins.readDir ./modules/nixos/config/hosts;
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
          modules.darwin.options
          modules.darwin.config
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
      network = let
        config = builtins.fromJSON (builtins.readFile ./network.json);
        emptyState = {
          serial = 0;
          peers = {};
          certs = {};
          revoked_serials = [];
        };
        state =
          if builtins.pathExists stateFile
          then builtins.fromJSON (builtins.readFile stateFile)
          else emptyState;
        # Merge credentials from state into peers
        peers =
          builtins.mapAttrs (
            name: peer:
              peer // (state.peers.${name} or {})
          )
          config.peers;
        allSubnets4 = builtins.map (s: s.subnet4) (builtins.attrValues config.sites);
        allSubnets6 = builtins.map (s: s.subnet6) (builtins.attrValues config.sites);
      in
        config // {inherit peers state allSubnets4 allSubnets6;};
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
