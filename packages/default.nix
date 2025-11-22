# packages.nix
{ pkgs }:
let
  packages = import ./packages { inherit pkgs; };
  envs = import ./envs { inherit pkgs; };
in
packages // { inherit envs; }
