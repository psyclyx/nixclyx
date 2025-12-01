{
  pkgs ? import <nixpkgs> { },
}:
let
  # Import shell and language environments
  shell = import ./shell pkgs;
  languages = import ./languages pkgs;

  # Import standalone environments
  llm = import ./llm.nix pkgs;
  media = import ./media.nix pkgs;
  "3dprinting" = import ./3dprinting.nix pkgs;
  forensics = import ./forensics.nix pkgs;
in
{
  # Expose shell and languages at top level
  inherit shell languages;

  # Expose standalone environments
  inherit llm media forensics;
  "3dprinting" = "3dprinting";
}
