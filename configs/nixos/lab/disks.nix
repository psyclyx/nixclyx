{
  inputs,
  config,
  lib,
  ...
}:
let

  inherit (lib)
    listToAttrs
    types
    mkEnableOption
    mkIf
    mkOption
    ;

  diskType = types.submodule {
    options = {
      id = mkOption { type = types.str; };
      name = mkOption { type = types.str; };
      group = mkOption { type = types.str; };
      boot = mkEnableOption "boot partition";
    };
  };

  idDevice = id: "/dev/disk/by-id/${id}";

  cfg = config.psyclyx.hosts.lab.disks;
in
{
  imports = [ inputs.disko.nixosModules.disko ];

  options = {
    psyclyx.hosts.lab.disks = {
      enable = mkEnableOption "disk partitioning/formatting";
      pool = mkOption { type = types.nullOr (types.listOf diskType); };
    };
  };

  config = mkIf cfg.enable {
    disko = {
      devices = {
        disk = listToAttrs (
          map (
            {
              id,
              name,
              group,
              boot,
            }:
            {
              inherit name;
              value = {
                device = idDevice id;
                type = "disk";
                content = {
                  type = "gpt";
                  partitions = {
                    ESP = mkIf boot {
                      type = "EF00";
                      size = "1G";
                      content = {
                        type = "filesystem";
                        format = "vfat";
                        mountpoint = "/boot";
                        mountOptions = [ "umask=0077" ];
                      };
                    };
                    bcache = {
                      size = "100%";
                      content = {
                        type = "bcachefs";
                        filesystem = "bpool";
                        label = "${group}.${name}";
                        extraFormatArgs = [
                          "--discard"
                          "--force"
                        ];
                      };
                    };
                  };
                };
              };
            }
          ) cfg.pool
        );

        bcachefs_filesystems = {
          bpool = {
            type = "bcachefs_filesystem";
            passwordFile = "/tmp/bpool.key";
            extraFormatArgs = [
              "--compression=lz4"
              "--replicas=2"
            ];

            subvolumes = {
              "nixos/root" = {
                mountpoint = "/";
                mountOptions = [ "verbose" ];
              };

              "nixos/nix" = {
                mountpoint = "/nix";
              };

              "nixos/var" = {
                mountpoint = "/var";
                mountOptions = [ "noatime" ];
              };

              "nixos/home" = {
                mountpoint = "/home";
              };

              "nixos/home/root" = {
                mountpoint = "/root";
              };
            };
          };
        };
      };
    };
  };
}
