{
  lib ? <nixpkgs>.lib,
}:
let
  inherit (lib) mapAttrs;

  imports = {
    checks = ./checks.nix;
  };

  importPath = path: import path { inherit lib psyclyxLib; };

  psyclyxLib = mapAttrs (_: importPath) imports;
in
psyclyxLib
