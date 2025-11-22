{
  lib ? <nixpkgs>.lib,
}:
let
  inherit (lib) mapAttrs;

  imports = {
    checks = ./checks.nix;
    darwin = ./darwin.nix;
    nixpkgs = ./nixpkgs.nix;
    packageSets = ./packageSets.nix;
    systems = ./systems.nix;
    test = ./test.nix;
  };

  importPath = path: import path { inherit lib psyclyxLib; };

  psyclyxLib = mapAttrs (_: importPath) imports;
in
psyclyxLib
