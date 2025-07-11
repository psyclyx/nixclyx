{ inputs, overlays }:
{
  hostName,
  hostPlatform,
  modules ? [ ],
  ...
}@args:
let
  inherit (inputs) nixpkgs;
in
nixpkgs.lib.nixosSystem {
  modules = [
    {
      networking.hostName = hostName;
      nixpkgs = {
        inherit overlays hostPlatform;
        config.allowUnfree = true;
        config.nvidia.acceptLicense = true;
      };
    }
  ] ++ modules;

  specialArgs = {
    inherit inputs;
  } // args;
}
