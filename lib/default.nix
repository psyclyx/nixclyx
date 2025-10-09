{
  lib ? <nixpkgs>.lib,
}:
let
  imports = {
    systems = ./systems.nix;
    packageSets = ./packageSets.nix;
    nixos = ./nixos.nix;
    nixpkgs = ./nixpkgs.nix;
  };
in
lib.fix (psyclyxLib: lib.mapAttrs (_: path: import path { inherit lib psyclyxLib; }) imports)
