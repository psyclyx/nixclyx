{ inputs, overlays }:
{
  hostName,
  hostPlatform,
  modules ? [ ],
  ...
}@args:
inputs.nixpkgs.lib.nixosSystem {
  system = hostPlatform;
  modules = [
    { networking.hostName = hostName; }
    { nixpkgs.overlays = overlays; }
    ./nixpkgs.nix
  ] ++ modules;

  specialArgs = {
    inherit inputs;
  } // args;
}
