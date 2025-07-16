{ pkgs }:
let
  emacs = pkgs.emacsWithPackagesFromUsePackage {
    config = ./config.org;
    package = pkgs.emacs-unstable-pgtk;
    extraEmacsPackages = epkgs: with pkgs; [];
  };
in
emacs
