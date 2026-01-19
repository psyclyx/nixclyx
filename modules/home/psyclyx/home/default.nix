{ inputs, ... }:
{
  imports = [
    inputs.ags.homeManagerModules.default
    inputs.sops-nix.homeManagerModules.sops
    ./programs
    ./roles
    ./services
    ./system
    ./info.nix
  ];

  config = {
    home.stateVersion = "25.11";
  };
}
