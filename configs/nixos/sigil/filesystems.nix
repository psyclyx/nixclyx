{ inputs, ... }:
{
  disko = {
    devices = {
      disk = {
        nvme0 = {
          device = "/dev/nvme0n1";
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              boot = {
                name = "boot";
                size = "1M";
                type = "EF02";
              };
              ESP = {
                size = "512M";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                };
              };
              swap = {
                size = "48G";
                content = {
                  type = "luks";
                  name = "cryptswap";
                  settings.allowDiscards = true;
                  passwordFile = "/tmp/secret.pass";
                  content = {
                    type = "swap";
                    randomEncryption = true;
                  };
                };
              };
              root = {
                size = "50G";
                content = {
                  type = "luks";
                  name = "cryptroot";
                  settings.allowDiscards = true;
                  passwordFile = "/tmp/secret.pass";
                  content = {
                    type = "filesystem";
                    format = "ext4";
                    mountpoint = "/";
                  };
                };
              };
              fast = {
                size = "100%";
                content = {
                  type = "luks";
                  name = "cryptfast";
                  settings.allowDiscards = true;
                  passwordFile = "/tmp/secret.pass";
                  content = {
                    type = "filesystem";
                    format = "ext4";
                    mountpoint = "/var/lib/fast";
                  };
                };
              };
            };
          };
        };
        nvme1 = {
          device = "/dev/nvme1n1";
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              nix = {
                size = "300G";
                content = {
                  type = "luks";
                  name = "cryptnix";
                  settings.allowDiscards = true;
                  passwordFile = "/tmp/secret.pass";
                  content = {
                    type = "filesystem";
                    format = "ext4";
                    mountpoint = "/nix";
                  };
                };
              };
              var = {
                size = "100G";
                content = {
                  type = "luks";
                  name = "cryptvar";
                  settings.allowDiscards = true;
                  passwordFile = "/tmp/secret.pass";
                  content = {
                    type = "filesystem";
                    format = "ext4";
                    mountpoint = "/var";
                  };
                };
              };
              home = {
                size = "100%";
                content = {
                  type = "luks";
                  name = "crypthome";
                  settings.allowDiscards = true;
                  passwordFile = "/tmp/secret.pass";
                  content = {
                    type = "filesystem";
                    format = "ext4";
                    mountpoint = "/home";
                  };
                };
              };
            };
          };
        };
        sda = {
          device = "/dev/sda";
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              bulk = {
                size = "100%";
                content = {
                  type = "luks";
                  name = "cryptgames";
                  settings.allowDiscards = true;
                  passwordFile = "/tmp/secret.pass";
                  content = {
                    type = "filesystem";
                    format = "ext4";
                    mountpoint = "/var/lib/bulk";
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
