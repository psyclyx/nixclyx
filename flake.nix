{
  description = "nixos/nix-darwin configurations";

  inputs = {
    # ==== Core ====

    # Main package repository
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    #nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";

    # Simple NixOS modules for common hardware configurations
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # NixOS-esque configuration for Darwin (MacOS)
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NixOS-esque configuration of home directories
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ==== Deploy ====

    # Declarative disk partitioning that doubles as NixOS config
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets decrypted at runtime, for NixOS/nix-darwin and home-manager
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ==== Programs ====

    # `nix-darwin` module to manage a homebrew installation
    # (`nix-darwin` can manage packages/casks from homebrew OOTB,
    #  but doesn't have support for installing homebrew itself)
    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };

    # Track newer versions of `emacs` (NixOS) and its package repositories
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs-stable";
    };

    # Track newer versions of `emacs` on Darwin
    nix-darwin-emacs = {
      url = "github:nix-giant/nix-darwin-emacs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs) lib;
      overlay = import ./overlay.nix;
      overlays = [
        overlay
        inputs.nix-darwin-emacs.overlays.emacs
        inputs.emacs-overlay.overlays.default
      ];

      pkgsFor =
        system:
        (import inputs.nixpkgs {
          inherit overlays system;
          config = {
            allowUnfree = true;
          };
        });
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      systemPkgs = lib.genAttrs systems pkgsFor;
      mapSystemPkgs = f: (lib.mapAttrs (_: f) systemPkgs);

      mkDarwinConfiguration = import ./modules/darwin { inherit inputs overlays; };
      mkNixosConfiguration = import ./modules/nixos { inherit inputs overlays; };
    in
    rec {
      packages = mapSystemPkgs (pkgs: pkgs.psyclyx);
      overlays.default = overlay;
      devShells = mapSystemPkgs (pkgs: {
        default = import ./shell.nix { inherit pkgs; };
      });
      homeManagerModules.default = ./modules/home/module.nix;

      nixosConfigurations = {
        ix = mkNixosConfiguration {
          modules = [ ./configs/nixos/ix ];
          system = "x86_64-linux";
        };
        omen = mkNixosConfiguration {
          modules = [ ./configs/nixos/omen ];
          system = "x86_64-linux";
        };
        sigil = mkNixosConfiguration {
          modules = [ ./configs/nixos/sigil ];
          system = "x86_64-linux";
        };
        tleilax = mkNixosConfiguration {
          modules = [ ./configs/nixos/tleilax ];
          system = "x86_64-linux";
        };
      };

      darwinConfigurations = {
        halo = mkDarwinConfiguration {
          hostPlatform = "aarch64-darwin";
          system = "aarch64-darwin";
          hostName = "halo";
          modules = [ ./configs/darwin/halo ];
        };
      };

      checks =
        let
          hostConfigs = nixosConfigurations // darwinConfigurations;
          hasSystem = system: hostConfig: hostConfig.pkgs.system == system;
          systemHostConfigs = system: (lib.filterAttrs (_: (hasSystem system)) hostConfigs);
          topLevel = hostConfig: hostConfig.config.system.build.toplevel;
          systemChecks = system: lib.mapAttrs (_: topLevel) (systemHostConfigs system);
        in
        lib.genAttrs systems systemChecks;
    };
}
