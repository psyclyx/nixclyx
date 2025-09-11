{ lib }:
{
  pkgs ? import <nixpkgs> { },
}:
{
  systems = import ./systems.nix;
  packageSets = import ./packageSets.nix { inherit pkgs; };
}
