{ inputs, config, ... }:
{
  imports = [ ./base.nix ];

  config = {
    networking.hostName = "lab-4";

    boot = {
      initrd = {
        systemd.network = {
          enable = true;
          networks.eno1 = {
            enable = true;
            DHCP = "yes";
          };
        };
        availableKernelModules = [
          "tg3"
          "mlx4_core"
        ];
      };
    };

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
  };

}
