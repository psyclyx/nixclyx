{ inputs, ... }:
{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
    ./programs
    ./roles
    ./services
    ./system
    ./user.nix
  ];
}
