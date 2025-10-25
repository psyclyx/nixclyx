{ inputs, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko
    ./boot
    ./hardware
    ./programs
    ./roles
    ./services
    ./stylix.nix
    ./system
  ];
}
