{ inputs, ... }:
let
  inherit (inputs)
    disko
    niri
    self
    stylix
    ;
in
{
  imports = [
    disko.nixosModules.disko
    niri.nixosModules.niri
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
