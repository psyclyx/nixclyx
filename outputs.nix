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

  inherit (psyclyxLib.darwin) mkDarwinConfiguration mkDarwinToplevels;
  darwinConfigurations = {
    halo = mkDarwinConfiguration inputs {
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

  common = import ./configs/common;

  passthrough = {
    inherit inputs;
  };

  inherit (psyclyxLib.nixos) mkNixosToplevels mkNixosImages;
  inherit (psyclyxLib.checks) mkChecks;

  nixosSystems = mkNixosToplevels nixosConfigurations;
  darwinSystems = mkDarwinToplevels darwinConfigurations;
  nixosImages = mkNixosImages nixosConfigurations;
  checks = mkChecks { inherit nixosConfigurations darwinConfigurations; };

in
{
  inherit
    assets
    checks
    common
    darwinSystems
    devShells
    darwinConfigurations
    nixosConfigurations
    nixosImages
    nixosSystems
    packages
    passthrough
    ;
  lib = psyclyxLib;
}
// moduleOutputs
