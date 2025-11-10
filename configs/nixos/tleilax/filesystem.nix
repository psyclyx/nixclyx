{ inputs, ... }:
{
  imports = [ inputs.disko.nixosModules.disko ];
  disko.devices = {
    disk.disk1 = {
      device = "/dev/disk/by-id/ata-CT2000MX500SSD1_2403E88EF849";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            type = "EF00";
            size = "100M";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
    disk.disk2 = {
      device = "/dev/disk/by-id/ata-CT2000MX500SSD1_2403E88EF894";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/var/lib/misc";
            };
          };
        };
      };
    };

    disk.disk3 = {
      device = "/dev/disk/by-id/ata-Samsung_SSD_870_EVO_2TB_S753NL0Y104917Y";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/var/lib/containers";
            };
          };
        };
      };
    };

    disk.disk4 = {
      device = "/dev/disk/by-id/ata-Samsung_SSD_870_EVO_2TB_S753NL0Y105029W";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/var/lib/misc2";
            };
          };
        };
      };
    };
  };
}
