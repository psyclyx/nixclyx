# packages.nix
{
  pkgs ? import <nixpkgs> { },
  psyclyxLib ? import ../lib { inherit pkgs; },
}:
let
  inherit (psyclyxLib.packageSets) mkPackageSet;
  packageDefs = import ./packageDefs.nix;
in
mkPackageSet packageDefs
