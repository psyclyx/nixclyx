let
  npins = import ./npins;
in
  {
    # The batch seam: every dep below defaults to this project's own pins.
    sources ? npins,
    # nixpkgs used to build hosts. Standalone: nixclyx's own pin; callers may
    # pass their own.
    nixpkgs ? sources.nixpkgs,
    # External deps — one arg each, defaulting to this project's own pins.
    astal ? sources.astal,
    clj-nix ? sources.clj-nix,
    colmena ? sources.colmena,
    disko ? sources.disko,
    flake-compat ? sources.flake-compat,
    home-manager ? sources.home-manager,
    # The pin names carry a `.nix` suffix; the args drop it.
    llm-agents ? sources."llm-agents.nix",
    microvm ? sources."microvm.nix",
    nix-darwin ? sources.nix-darwin,
    nix-homebrew ? sources.nix-homebrew,
    nixos-anywhere ? sources.nixos-anywhere,
    nixos-apple-silicon ? sources.nixos-apple-silicon,
    nvf ? sources.nvf,
    preservation ? sources.preservation,
    robotnix ? sources.robotnix,
    rustfs-flake ? sources.rustfs-flake,
    sops-nix ? sources.sops-nix,
    stylix ? sources.stylix,
    # Source paths for the internal producers (river, shoal, tidepool,
    # whirlpool, base24-gen, emacs, pi-nix, fix, psyclight). Default {} => this repo's
    # own npins pins (standalone). Callers override entries so BOTH the
    # producer overlays and the home-manager module imports track the
    # injected sources.
    internalSources ? {},
    ...
  }: let
    # Phase 1: Core — standalone values with no module dependencies.
    # The pins map every consumer below reads: own pins as the base (the
    # standalone-only pins like nixpkgs live there), then the batch
    # seam, then the named dep args (so single-dep overrides win), then the
    # internalSources seam (unchanged).
    allSources =
      npins
      // sources
      // {
        inherit
          astal
          clj-nix
          colmena
          disko
          flake-compat
          home-manager
          nix-darwin
          nix-homebrew
          nixos-anywhere
          nixos-apple-silicon
          nvf
          preservation
          robotnix
          rustfs-flake
          sops-nix
          stylix
          ;
        "llm-agents.nix" = llm-agents;
        "microvm.nix" = microvm;
      }
      // internalSources;
    loadFlake = import ./loadFlake.nix {inherit flake-compat;};
    lib = import ./lib;
    overlay = import ./overlays.nix {
      sources = allSources;
      inherit flake-compat;
    };
    packages = import ./packages;

    core = {
      sources = allSources;
      inherit loadFlake lib overlay packages;
      assets = ./assets;
      keys = import ./data/keys.nix;
      # Each group keeps only what builds on the host's platform (the lists
      # are written for Linux; darwin and mobile hosts share them).
      packageGroups = builtins.mapAttrs (_: group: pkgs:
        builtins.filter (p:
          pkgs.lib.meta.availableOn pkgs.stdenv.hostPlatform p
          && !(p.meta.broken or false))
        (group pkgs))
      (import ./data/packageGroups.nix);
      nixCaches = import ./data/nixCaches.nix;
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

    darwinSystem = (loadFlake allSources.nix-darwin).lib.darwinSystem;

    # One nix-darwin system per ./hosts/darwin/<name>, built against the
    # injected nixpkgs rather than nix-darwin's own lock.
    darwinHostEntries = builtins.readDir ./hosts/darwin;
    darwinConfigurations = builtins.listToAttrs (map (name: {
        inherit name;
        value = darwinSystem {
          # nix-darwin defaults lib to its own lock; match the injected pkgs.
          lib = import (nixpkgs + "/lib");
          modules = [
            modules.darwin
            {nixpkgs.source = nixpkgs;}
            ./hosts/darwin/${name}
          ];
        };
      })
      (builtins.filter
        (n: darwinHostEntries.${n} == "directory")
        (builtins.attrNames darwinHostEntries)));

    nixOnDroidLib = (loadFlake allSources.nix-on-droid).lib;

    mkDroidHost = name:
      nixOnDroidLib.nixOnDroidConfiguration {
        pkgs = import nixpkgs {system = "aarch64-linux";};
        home-manager-path = allSources.home-manager.outPath;
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
    egregorePkg = import egregoreSpec.lib {inherit (hostPkgs) lib;};
    fleet = egregorePkg.eval {modules = [egregoreSpec.root];};

    mkSwitchSystem = platform: platformDir: projection: name:
      (import platformDir {
        lib = hostPkgs.lib;
        pkgs = hostPkgs;
      }).eval {
        modules = [projection];
        specialArgs = {
          egregore = fleet;
          egregorLib = egregorePkg.lib;
          deviceName = name;
        };
      };

    # A switch system exists for every entity presenting the platform's
    # kind (`e.<kind> != null` — the type of an entity is the name of the
    # kind that is present, model §4).
    systemsOfType = kind: platformDir: projection:
      hostPkgs.lib.mapAttrs
      (name: _: mkSwitchSystem kind platformDir projection name)
      (hostPkgs.lib.filterAttrs (_: e: (e.${kind} or null) != null) fleet.entities);

    # Device CLIs (generic, connection-agnostic). Home modules put these on
    # PATH; the deploy scripts compose them. Egregore-unaware on purpose.
    platformTools = {
      swos =
        (import ./lib/platform/swos {
          lib = hostPkgs.lib;
          pkgs = hostPkgs;
        }).cli;
      sodola =
        (import ./lib/platform/sodola {
          lib = hostPkgs.lib;
          pkgs = hostPkgs;
        }).cli;
      ilo =
        (import ./lib/platform/ilo {
          lib = hostPkgs.lib;
          pkgs = hostPkgs;
        }).cli;
    };

    # The full nixclyx attrset. Modules see this via _module.args (lazy).
    # hive/configurations/darwinConfigurations are top-level consumers only —
    # no module spec should reference them.
    nixclyx =
      core
      // {
        inherit nixpkgs hostPkgs nodes deployments modules hive configurations darwinConfigurations nixOnDroidConfigurations;
        inherit fleet platformTools;
        routerosSystems = systemsOfType "routeros" ./lib/platform/routeros ./modules/routeros/projection.nix;
        swosSystems = systemsOfType "swos" ./lib/platform/swos ./modules/swos/projection.nix;
        sodolaSystems = systemsOfType "sodola" ./lib/platform/sodola ./modules/sodola/projection.nix;
        iloSystems = systemsOfType "ilo" ./lib/platform/ilo ./modules/ilo/projection.nix;
        hosts.nixos = builtins.listToAttrs (map (name: {
            inherit name;
            value = ./hosts/nixos + "/${name}";
          })
          hostNames);
        overlays.default = overlay;
        docs = import ./docs {inherit nixclyx;};
        fleet-viz = pkgs: let
          spec = import ./egregore.nix;
          egregorePkg = import spec.lib {inherit (pkgs) lib;};
          egregorData = egregorePkg.eval {modules = [spec.root];};
        in
          import ./packages/fleet-viz {
            inherit pkgs egregorData;
          };
        nvf = pkgs:
          ((import allSources.nvf).lib.neovimConfiguration {
            inherit pkgs;
            modules = [
              modules.nvf
              {psyclyx.nvf.roles.base.enable = true;}
            ];
          }).neovim;
      };
  in
    nixclyx
