{pkgs}:
pkgs.callPackage "${(import ../../npins)."base24-gen"}/package.nix" {}
