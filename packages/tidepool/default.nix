{ pkgs }:
pkgs.callPackage "${(import ../../npins).tidepool}/package.nix" {}
