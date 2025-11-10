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

  packageGroups = import ./package-groups;

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
    inherit (lib) nixosSystem;
    specialArgs = { inherit inputs; };
  };

  common = import ./configs/common;

  passthrough = {
    inherit inputs;
  };

  inherit (psyclyxLib.checks) mkChecks;

  checks = mkChecks { inherit nixosConfigurations darwinConfigurations; };

in
{
  inherit
    assets
    checks
    common
    devShells
    darwinConfigurations
    nixosConfigurations
    packages
    packageGroups
    passthrough
    ;
  lib = psyclyxLib;
}
// moduleOutputs
