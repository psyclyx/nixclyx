{ inputs, ... }:
let
  inherit (inputs)
    disko
    self
    stylix
    ;
in
{
  imports = [
    disko.nixosModules.disko
    stylix.nixosModules.stylix
    self.commonModules.nixos
    ./boot
    ./filesystems
    ./programs
    ./services
    ./system
  ];

  config = {
    system.stateVersion = "25.11";
  };
}
