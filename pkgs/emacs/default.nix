{ pkgs }:
let
  emacs = pkgs.emacsWithPackagesFromUsePackage {
    config = ./config.org;
    defaultInitFile = true;
    alwaysTangle = true;
    package = pkgs.emacs-unstable-pgtk;
  };
in
emacs
