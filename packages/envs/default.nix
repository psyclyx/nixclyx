{ pkgs }:
let
  inherit (builtins) mapAttrs;

  mkEnv = envDef: envDef pkgs;

  envDefs = {
    shell-utils = ./shell-utils.nix;
  };
in
mapAttrs (_: mkEnv) envDefs
