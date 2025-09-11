{ lib }:
{
  pkgs ? import <nixpkgs> { },
}:
{
  platforms = import ./platforms.nix;
  packageSets = import ./packageSets.nix { inherit pkgs; };
}
