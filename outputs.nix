inputs:
let
  inherit (inputs) nixpkgs;
  inherit (nixpkgs) lib;

  psyclyxLib = import ./lib { inherit lib; };

  inherit (psyclyxLib.files) dirToAttrset;
  assets = dirToAttrset ./assets;

  inherit (psyclyxLib.systems) genSystemPkgsAttrs;
  withSystemPkgs = f: genSystemPkgsAttrs nixpkgs f;

  mkDevShells = pkgs: {
    default = import ./shell.nix { inherit pkgs; };
  };
  devShells = withSystemPkgs mkDevShells;

  mkPackages = pkgs: import ./packages { inherit pkgs; };
  packages = withSystemPkgs mkPackages;

  mkDarwinConfiguration = import ./modules/darwin { inherit inputs; };
  darwinConfigurations = {
    halo = mkDarwinConfiguration {
      hostPlatform = "aarch64-darwin";
      system = "aarch64-darwin";
      hostName = "halo";
      modules = [ ./configs/darwin/halo ];
    };
  };

  moduleOutputs = import ./modules;

  nixosConfigurations = import ./configs/nixos {
    inherit psyclyxLib;
    specialArgs = { inherit inputs; };
  };

in
{
  inherit
    assets
    devShells
    darwinConfigurations
    nixosConfigurations
    packages
    ;
  lib = psyclyxLib;
}
// moduleOutputs
