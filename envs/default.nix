{
  pkgs ? import <nixpkgs> { },
}:
let
  # Import shell and language environments
  shell = import ./shell pkgs;
  languages = import ./languages pkgs;
in
{
  # Expose shell and languages at top level
  inherit shell languages;
}
