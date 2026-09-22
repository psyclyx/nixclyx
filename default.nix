{
  # nixpkgs used to build hosts. Standalone: nixclyx's own pin. The monorepo
  # superproject passes the shared lib/nixpkgs.
  nixpkgs ? (import ./npins).nixpkgs,
  # Sibling sources for the internal producers (river/shoal/tidepool/
  # base24-gen/emacs). Default {} => use nixclyx's own npins pins
  # (standalone). The monorepo superproject overrides these with the sibling
  # checkouts, so BOTH the producer overlays and the home-manager module
  # imports track the monorepo versions.
  internalSources ? { },
}:
let
  # Phase 1: Core — standalone values with no module dependencies.
  sources = (import ./npins) // internalSources;
  loadFlake = import ./loadFlake.nix;
  lib = import ./lib;
  overlay = import ./overlays.nix { inherit sources; };
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
  hostEntries = builtins.readDir ./hosts/nixos;
  hostNames =
    builtins.filter
    (n: hostEntries.${n} == "directory")
    (builtins.attrNames hostEntries);

  # The pkgs every host is built against: injected nixpkgs + the
  # injection-aware overlay. Shared by `configurations` (below) and the
  # hive's meta.nixpkgs, so both build against exactly the same set.
  hostPkgs = import ./nixpkgs.nix {
    inherit nixpkgs;
    overlays = [overlay];
  };

  # The deployment-free definition of each host, and the Colmena metadata
  # keyed by the same names. `nodes` is the single source both consumers
  # derive from; `deployments` only feeds the hive.
  nodes = import ./nodes.nix {inherit nixclyx;};
  deployments = import ./deployments.nix {
    inherit nixclyx;
    lib = hostPkgs.lib;
  };

  # Plain NixOS systems from `nodes` — no Colmena, no deployment. Point
  # `nixos-rebuild -A configurations.<host>` at these; eval-config leaves
  # each under `.config.system.build.toplevel`.
  evalConfig = import (nixpkgs + "/nixos/lib/eval-config.nix");
  configurations = builtins.mapAttrs (name: node:
    evalConfig {
      system = hostPkgs.stdenv.hostPlatform.system;
      specialArgs = {inherit name;};
      modules = [node];
    })
  nodes;

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
      pkgs = import nixpkgs {system = "aarch64-linux";};
      home-manager-path = sources.home-manager.outPath;
      modules = [
        modules.nix-on-droid
        {config.psyclyx.droid.host = name;}
      ];
    };

  nixOnDroidConfigurations = builtins.mapAttrs (name: _: mkDroidHost name) {
    phone = {};
  };

  hive = import ./hive.nix {inherit nodes deployments hostPkgs;};

  # The fleet graph, evaluated once, and the platform systems derived from
  # it. Each switch gets a `lib/platform/<p>` eval whose projection module
  # reads this graph; the result exposes `config.system.build.{json,script}`
  # the way a NixOS system exposes `toplevel`. Build/deploy tooling reads
  # these; nothing here knows about deployment targets.
  egregoreSpec = import ./egregore.nix;
  egregorePkg = import egregoreSpec.lib { inherit (hostPkgs) lib; };
  fleet = egregorePkg.eval { modules = [ egregoreSpec.root ]; };

  mkSwitchSystem = platform: platformDir: projection: name:
    (import platformDir { lib = hostPkgs.lib; pkgs = hostPkgs; }).eval {
      modules = [ projection ];
      specialArgs = {
        egregore = fleet;
        egregorLib = egregorePkg.lib;
        deviceName = name;
      };
    };

  systemsOfType = type: platformDir: projection:
    hostPkgs.lib.mapAttrs
      (name: _: mkSwitchSystem type platformDir projection name)
      (hostPkgs.lib.filterAttrs (_: e: e.type == type) fleet.entities);

  # The full nixclyx attrset. Modules see this via _module.args (lazy).
  # hive/configurations/darwinConfigurations are top-level consumers only —
  # no module spec should reference them.
  nixclyx =
    core
    // {
      inherit nixpkgs hostPkgs nodes deployments modules hive configurations darwinConfigurations nixOnDroidConfigurations;
      inherit fleet;
      routerosSystems = systemsOfType "routeros" ./lib/platform/routeros ./modules/routeros/projection.nix;
      swosSystems = systemsOfType "swos" ./lib/platform/swos ./modules/swos/projection.nix;
      sodolaSystems = systemsOfType "sodola" ./lib/platform/sodola ./modules/sodola/projection.nix;
      iloSystems = systemsOfType "ilo" ./lib/platform/ilo ./modules/ilo/projection.nix;
      hosts.nixos = builtins.listToAttrs (map (name: {
        inherit name;
        value = ./hosts/nixos + "/${name}";
      }) hostNames);
      overlays.default = overlay;
      docs = import ./docs {inherit nixclyx;};
      fleet-viz = pkgs: let
        spec = import ./egregore.nix;
        egregorePkg = import spec.lib { inherit (pkgs) lib; };
        egregorData = egregorePkg.eval { modules = [spec.root]; };
      in import ./packages/fleet-viz {
          inherit pkgs egregorData;
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
