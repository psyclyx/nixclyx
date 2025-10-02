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
    ../../../modules/nixos/module.nix

    ../../../modules/nixos/services/fail2ban.nix

    #./containers.nix
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

    roles = {
      base.enable = true;
      remote.enable = true;
      utility.enable = true;
    };
    services = {
      openssh = {
        enable = true;
      };
      locate.users = [ "psyc" ];
      tailscale = {
        enable = true;
        exitNode = true;
      };
    };

    system = {
      home-manager.enable = true;
      sudo = {
        enable = true;
      };
    };
  };
}
