{
  inputs,
  pkgs,
  ...
}:
{
  imports = [ inputs.self.nixosModules.config ];

  config = {
    boot = {
      initrd = {
        availableKernelModules = [
          "tg3"
          "mlx4_core"
        ];

        systemd = {
          enable = true;
          network = {
            enable = true;
            networks."10-eno1" = {
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

    fileSystems = {
      "/" = {
        device = "LABEL=bcachefs";
        fsType = "bcachefs";
      };
      "/boot" = {
        # all disks have space for /boot, only one ever actually has it
        device = "PARTLABEL=boot";
        fsType = "vfat";
        options = [ "umask=0077" ];
      };
    };

    psyclyx = {
      hardware.presets.hpe.dl360-gen9.enable = true;

      boot = {
        systemd-boot.enable = true;
        initrd-ssh.enable = true;
      };

      filesystems.bcachefs.enable = true;

      roles = {
        base.enable = true;
        remote.enable = true;
        utility.enable = true;
      };

      system = {
        containers.enable = true;
        swap.enable = true;
      };

      users.psyc = {
        enable = true;
        server = true;
      };
    };
  };
}
