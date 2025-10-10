{ inputs, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko
    ./boot
    ./hardware
    ./network
    ./programs
    ./roles
    ./services
    ./stylix.nix
    ./system
  ];
}
