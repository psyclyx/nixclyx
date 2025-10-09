{ inputs, ... }:
let
  inherit (inputs) disko self;
in
{
  system.stateVersion = "25.05";
  networking.hostName = "ix";
  time.timeZone = "America/Los_Angeles";
  imports = [
    self.nixosModules.psyclyx

    ./boot.nix
    ./filesystems.nix
    ./hardware.nix
    ./network.nix
    ./users.nix
  ];

  psyclyx = {
    services = {
      openssh = {
        enable = true;
      };
      tailscale = {
        enable = true;
        exitNode = true;
      };
    };

    system = {
      sudo = {
        enable = true;
      };
    };
  };
}
