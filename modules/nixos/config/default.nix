{ inputs, ... }:
let
  inherit (inputs) disko self stylix;
in
{
  imports = [
    disko.nixosModules.disko
    stylix.nixosModules.stylix
    self.commonModules.config
    ./boot
    ./filesystems
    ./hardware
    ./network
    ./programs
    ./roles
    ./services
    ./system
    ./users
  ];

  config = {
    system.stateVersion = "25.05";
  };
}
