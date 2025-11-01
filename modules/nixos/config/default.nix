{ inputs, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko
    ./boot
    ./filesystems
    ./hardware
    ./programs
    ./roles
    ./services
    ./stylix.nix
    ./system
  ];
}
