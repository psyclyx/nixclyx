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
    {
      nixpkgs = {
        inherit overlays;
        config = {
          allowUnfree = true;
          nvidia.acceptLicense = true;
        };
      };
    }
  ] ++ modules;

  specialArgs = {
    inherit inputs;
  } // args;
}
