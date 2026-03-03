{ pkgs }:
pkgs.callPackage "${(import ../../npins).shoal}/package.nix" {}
