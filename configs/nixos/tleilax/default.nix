{
  inputs,
  modulesPath,
  pkgs,
  ...
}:
let
in
{
  system.stateVersion = "25.05";
  networking.hostName = "tleilax";
  time.timeZone = "America/Los_Angeles";
  imports = [
    inputs.stylix.nixosModules.stylix
    ../../../modules/nixos/module.nix
    ../../../modules/nixos/system/home-manager.nix

    ../../../modules/nixos/services/fail2ban.nix

    ./users.nix
    ./network.nix
    ./hardware.nix
    ./filesystems.nix
    ./nginx.nix
    ./metrics.nix
  ];

  boot.loader.systemd-boot.enable = true;

  psyclyx = {
    networking = {
      ports = {
        ssh = [ 17891 ];
      };
    };

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
