{ inputs, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko
    ./boot
    ./filesystems
    ./hardware
    ./network
    ./programs
    ./roles
    ./services
    ./stylix.nix
    ./system
    ./users
  ];
}
