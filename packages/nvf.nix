{pkgs}:
let
  nixclyx = import ../.;
in
nixclyx.nvf pkgs
