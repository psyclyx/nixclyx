{ inputs, overlays }:
{
  system,
  modules ? [ ],
  ...
}@args:
inputs.nixpkgs.lib.nixosSystem {
  inherit system;
  modules = [
    { nixpkgs.overlays = overlays; }
    ./nixpkgs.nix
  ] ++ modules;

  specialArgs = {
    inherit inputs;
  } // args;
}
