{
  lib ? (import <nixpkgs> { }).lib,
  psyclyxLib ? import ../lib { inherit lib; },
  ...
}:
let
  inherit (lib) runTests;

  libTests = import ./lib { inherit lib psyclyxLib; };

  runLibTests = runTests libTests;
in
{
  inherit libTests runLibTests;
}
