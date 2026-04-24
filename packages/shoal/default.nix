{ callPackage }:
let
  shoal-src = (import ../../npins).shoal;
  shoal-npins = import "${shoal-src}/npins";
in
callPackage "${shoal-src}/package.nix" {
  snail-src = shoal-npins.snail;
}
