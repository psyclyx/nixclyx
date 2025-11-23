{
  pkgs ? import <nixpkgs>,
}:
let
  inherit (pkgs.lib) mapAttrs;
  mkEnvs = mapAttrs (_: mkEnv: mkEnv pkgs);
in
mkEnvs {
  shell-utils = ./shell-utils.nix;
}
