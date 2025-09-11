# packages.nix
{
  pkgs ? import <nixpkgs> { },
  psyclyxLib ? import ../lib { inherit pkgs; },
}:
let
  inherit (psyclyxLib.packageSets) mkPackageSet;
  defs = import ./defs.nix;
in
mkPackageSet defs
