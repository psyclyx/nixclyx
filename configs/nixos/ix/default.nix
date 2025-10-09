{ inputs, ... }:
let
  inherit (inputs) disko;
in
{
  system.stateVersion = "25.05";
  networking.hostName = "ix";
  time.timeZone = "America/Los_Angeles";
  imports = [
    ../../../modules/nixos/module.nix

    ../../../modules/nixos/services/soju.nix

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
