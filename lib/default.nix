{
  lib ? <nixpkgs>.lib,
}:
let
  inherit (lib) mapAttrs;

  imports = {
    darwin = ./darwin.nix;
    files = ./files.nix;
    network = ./network;
    nixos = ./nixos.nix;
    nixpkgs = ./nixpkgs.nix;
    packageSets = ./packageSets.nix;
    systems = ./systems.nix;
    test = ./test.nix;
  };

  importPath = path: import path { inherit lib psyclyxLib; };

  psyclyxLib = mapAttrs (_: importPath) imports;
in
psyclyxLib
