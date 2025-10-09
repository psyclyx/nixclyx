{
  inputs,
  modulesPath,
  pkgs,
  ...
}:
let
  inherit (inputs) self;
in
{
  networking.hostName = "tleilax";

  imports = [
    self.nixosModules.psyclyx

    #./containers.nix
    ./users.nix
    ./network.nix
    ./hardware.nix
    ./filesystems.nix
    ./nginx.nix
    ./metrics.nix
  ];

  boot.loader.systemd-boot.enable = true;

  services.fail2ban = {
    enable = true;
    maxretry = 5;
    ignoreIP = [ "100.64.0.0/10" ];
    bantime = "1h";
    bantime-increment = {
      enable = true;
      multipliers = "1 2 4 8 16 32 64";
      maxtime = "168h";
      overalljails = true;
    };
  };

  psyclyx = {
    network = {
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
