{ inputs, config, ... }:
{
  imports = [ ./base.nix ];

  config = {
    networking.hostName = "lab-4";

    boot = {
      kernelParams = [ "ip=::::${config.networking.hostName}::dhcp" ];
      initrd = {
        availableKernelModules = [
          "tg3"
          "mlx4_core"
        ];
        systemd.network = {
          enable = true;
          config.DHCP = true;
        };
      };
    };

    psyclyx = {
      hosts.lab.disks = {
        enable = true;
        pool = [
          {
            id = "ata-LK0800GEYMU_BTHC6230013F800NGN";
            name = "a";
            group = "ssd";
            boot = true;
          }
          {
            id = "ata-LK0800GEYMU_BTHC6403075M800NGN";
            name = "b";
            group = "ssd";
          }
          {
            id = "ata-LK0800GEYMU_BTHC6162030P800NGN";
            name = "c";
            group = "ssd";
          }
          {
            id = "ata-LK0800GEYMU_BTHC624302D3800NGN";
            name = "d";
            group = "ssd";
          }
          {
            id = "ata-LK0800GEYMU_BTHC623100VD800NGN";
            name = "f";
            group = "ssd";
          }
        ];
      };
    };
  };
}
