{ inputs, ... }:
let
  inherit (inputs) disko self;
in
{
  imports = [
    disko.nixosModules.disko
    self.commonModules.config
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

  config = {
    system.stateVersion = "25.05";
  };
}
