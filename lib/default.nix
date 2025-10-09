{
  lib ? <nixpkgs>.lib,
}:
let
  imports = {
    files = ./files.nix;
    nixos = ./nixos.nix;
    nixpkgs = ./nixpkgs.nix;
    packageSets = ./packageSets.nix;
    systems = ./systems.nix;
  };
in
lib.fix (psyclyxLib: lib.mapAttrs (_: path: import path { inherit lib psyclyxLib; }) imports)
