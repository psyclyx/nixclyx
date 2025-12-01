{ pkgs ? import <nixpkgs> { }, ... }:
{
  _3DPrinting = import ./3DPrinting.nix pkgs;
  forensics = import ./forensics.nix pkgs;
  languages = import ./languages pkgs;
  llm = import ./llm.nix pkgs;
  media = import ./media.nix pkgs;
  shell = import ./shell pkgs;
}
