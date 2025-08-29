{
  description = "nixos/nix-darwin configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    psyclyx-emacs.url = "git+file:submodules/emacs";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko.url = "github:nix-community/disko";
    sops-nix.url = "github:Mic92/sops-nix";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs) lib;
      overlay = import ./overlay.nix inputs;
      overlays = [ overlay ];
      pkgsFor =
        system:
        (import inputs.nixpkgs {
          inherit overlays system;
          config.allowUnfree = true;
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

  nixConfig = {
    extra-substituters = [
      "https://psyclyx.cachix.org?priority=0"
      "https://nix-community.cachix.org?priority=1"
    ];
    extra-trusted-public-keys = [
      "psyclyx.cachix.org-1:UFwKXEDn3gLxIW9CeXGdFFUzCIjj8m6IdAQ7GA4XfCk="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };
}
