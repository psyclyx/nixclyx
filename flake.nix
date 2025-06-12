{
  description = "nixos/nix-darwin configurations";

  inputs = {
    # ==== Core ====

    # Main package repository
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";

    # Nix user repository
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    # ==== Non-flakes ====

    # `zsh` prompt
    powerlevel10k = {
      url = "github:romkatv/powerlevel10k";
      flake = false;
    };

    # ---- Homebrew taps ----

    # Base taps
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
  };

  outputs =
    inputs:
    let
      inherit (inputs)
        nixpkgs
        nixpkgs-master
        nur
        nix-darwin-emacs
        emacs-overlay
        ;
      inherit (nixpkgs) lib;

      overlays = [
        (import ./pkgs)
        nur.overlays.default
        nix-darwin-emacs.overlays.emacs
        emacs-overlay.overlays.default

        (
          final: prev:
          let
            system = prev.stdenv.hostPlatform.system;
          in
          {
            tailscale = nixpkgs-master.legacyPackages.${system}.tailscale;
          }
        )
      ];

      mkDarwinConfiguration = import ./modules/platform/darwin { inherit inputs overlays; };
      mkNixosConfiguration = import ./modules/platform/nixos { inherit inputs overlays; };

      pkgsFor =
        system:
        import nixpkgs {
          inherit system overlays;
          config.allowUnfree = true;
        };
    in
    {
      devShells = lib.genAttrs [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ] (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              age
              nixfmt-rfc-style
              nixd
              sops
              ssh-to-age
            ];
          };
        }
      );

      overlays.default = import ./pkgs;

      darwinConfigurations = {
        halo = mkDarwinConfiguration {
          hostPlatform = "aarch64-darwin";
          system = "aarch64-darwin";
          hostName = "halo";
          modules = [ ./hosts/halo ];
        };
      };

      nixosConfigurations = {
        omen = mkNixosConfiguration {
          hostPlatform = "x86_64-linux";
          hostName = "omen";
          modules = [ ./hosts/omen ];
        };
        sigil = mkNixosConfiguration {
          hostPlatform = "x86_64-linux";
          hostName = "sigil";
          modules = [ ./hosts/sigil ];
        };
        ix = mkNixosConfiguration {
          hostPlatform = "x86_64-linux";
          hostName = "ix";
          modules = [ ./hosts/ix ];
        };
        tleilax = mkNixosConfiguration {
          hostPlatform = "x86_64-linux";
          hostName = "tleilax";
          modules = [ ./hosts/tleilax ];
        };
        tleilax-iso = mkNixosConfiguration {
          hostPlatform = "x86_64-linux";
          hostName = "tleilax";
          modules = [
            ./modules/platform/nixos/iso.nix
            ./hosts/tleilax
          ];
        };
      };

      # For cache
      packages = {
        "aarch64-darwin".emacs = (pkgsFor "aarch64-darwin").emacs-30;
        "x86_64-linux".emacs = (pkgsFor "x86_64-linux").emacs30-pgtk;
      };
    };
}
