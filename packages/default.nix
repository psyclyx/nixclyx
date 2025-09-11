# packages.nix
{
  pkgs ? import <nixpkgs> { },
  system ? pkgs.system,
}:
let
  inherit (pkgs) lib callPackage;
  mkSupportedPackageSet = (import ../lib { inherit pkgs; }).packageSets.mkSupportedPackageSet;
  packageDefs = {
    upscale-image.path = ./upscale-image;
    print256colors.path = ./print256colors.nix;
  };
in
mkSupportedPackageSet packageDefs
