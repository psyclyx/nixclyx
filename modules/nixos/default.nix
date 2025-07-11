{ inputs, overlays }:
{
  system,
  modules ? [ ],
  ...
}@args:
inputs.nixpkgs.lib.nixosSystem {
  inherit system modules;
  specialArgs = {
    inherit inputs overlays;
  } // args;
}
