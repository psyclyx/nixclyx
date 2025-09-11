{ inputs }:
{
  system,
  modules ? [ ],
  ...
}@args:
inputs.nixpkgs.lib.nixosSystem {
  inherit system modules;
  specialArgs = {
    inherit inputs;
  }
  // args;
}
