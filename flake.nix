{
  description = "nixos/nix-darwin configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    psyclyx-emacs.url = "git+file:submodules/emacs";
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

  outputs =
    { nixpkgs, ... }@inputs:
    let
      inherit (nixpkgs) lib;
      psyclyxLib = import ./lib { inherit lib; };

      withSystemPkgs = with psyclyxLib.systems; f: genSystemPkgsAttrs nixpkgs f;

      moduleOutputs = import ./modules;

      perSystemOutputs = {
        devShells = withSystemPkgs (pkgs: {
          default = import ./shell.nix { inherit pkgs; };
        });

        packages = withSystemPkgs (pkgs: import ./packages { inherit pkgs; });
      };

      hostOutputs = {
        nixosConfigurations = import ./configs/nixos {
          inherit psyclyxLib;
          specialArgs = { inherit inputs; };
        };

        darwinConfigurations =
          let
            mkDarwinConfiguration = import ./modules/darwin { inherit inputs; };
          in
          {
            halo = mkDarwinConfiguration {
              hostPlatform = "aarch64-darwin";
              system = "aarch64-darwin";
              hostName = "halo";
              modules = [ ./configs/darwin/halo ];
            };
          };
      };

      outputs = {
        assets = psyclyxLib.files.dirToAttrset ./assets;
        lib = psyclyxLib;
      }
      // moduleOutputs
      // perSystemOutputs
      // hostOutputs;
    in
    outputs;
}
