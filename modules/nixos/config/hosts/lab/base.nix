{
  config,
  lib,
  pkgs,
  ...
}: let
  anyLab =
    config.psyclyx.nixos.config.hosts.lab-1.enable
    || config.psyclyx.nixos.config.hosts.lab-2.enable
    || config.psyclyx.nixos.config.hosts.lab-3.enable
    || config.psyclyx.nixos.config.hosts.lab-4.enable;
in {
  config = lib.mkIf anyLab {
    boot = {
      initrd = {
        systemd = {
          network = {
            networks."10-ethernet-dhcp" = {
              enable = true;
              matchConfig.Name = "et* en*";
              DHCP = "yes";
            };
          };
        };
      };
    };

    environment.systemPackages = [
      pkgs.psyclyx.envs.forensics
    ];

    psyclyx.nixos = {
      boot = {
        initrd-ssh.enable = true;
      };

      filesystems.layouts.bcachefs-pool.enable = true;

      hardware.presets.hpe.dl360-gen9.enable = true;

      config = {
        roles.server.enable = true;
      };
    };
  };
}
