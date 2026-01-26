{ inputs, ... }:
let
  inherit (inputs)
    niri
    self
    stylix
    ;
in
{
  imports = [
    niri.nixosModules.niri
    stylix.nixosModules.stylix
    self.commonModules.nixos
    ./boot
    ./filesystems
    ./hardware
    ./programs
    ./services
    ./system
  ];

  config = {
    system.stateVersion = "25.11";
  };
}
