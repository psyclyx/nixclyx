{ inputs, ... }:
let
  inherit (inputs)
    disko
    self
    stylix
    preservation
    ;
in
{
  imports = [
    disko.nixosModules.disko
    stylix.nixosModules.stylix
    preservation.nixosModules.preservation
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
    system.stateVersion = "25.11";
  };
}
