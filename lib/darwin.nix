{ lib, ... }:
let
  mkDarwinConfiguration =
    inputs:
    {
      hostName,
      hostPlatform,
      modules ? [ ],
      overlays ? [ ],
      ...
    }@args:
    let
      inherit (inputs) nix-darwin;

      defaultModules = [
        (
          { lib, ... }:
          {
            system.stateVersion = lib.mkDefault 5;
            networking.hostName = hostName;
            nixpkgs = {
              inherit overlays hostPlatform;
              config.allowUnfree = true;
            };
          }
        )
      ];
    in
    nix-darwin.lib.darwinSystem {
      modules = defaultModules ++ modules;
      specialArgs = {
        inherit inputs;
      } // args;
    };
in
{
  inherit mkDarwinConfiguration;
}
