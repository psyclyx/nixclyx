{
  inputs,
  config,
  lib,
  ...
}:
let

  inherit (lib)
    genAttrs'
    types
    mkDefault
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    nameValuePair
    ;

  inherit (builtins) length elemAt;

  diskType = types.submodule {
    options = {
      id = mkOption { type = types.str; };
      name = mkOption { type = types.str; };
      group = mkOption { type = types.str; };
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

  config = mkIf cfg.enable (mkMerge [
    {
      disko.devices.disk =
        let
          boot = elemAt cfg.pool 0;
        in
        {
          "${boot.name}" = {
            device = idDevice boot.id;
            type = "disk";
            content = {
              type = "gpt";
              partitions = {
                ESP = {
                  type = "EF00";
                  size = "1G";
                  content = {
                    type = "filesystem";
                    format = "vfat";
                    mountpoint = "/boot";
                    mountOptions = [ "umask=0077" ];
                  };
                };
              };
            };
          };
        };
    }

    {
      disko = {
        devices = {
          disk = genAttrs' cfg.pool (
            {
              id,
              name,
              group,
            }:
            nameValuePair name {
              device = idDevice id;
              type = "disk";
              content = {
                type = "gpt";
                partitions = {
                  bcache = {
                    size = "100%";
                    content = {
                      type = "bcachefs";
                      filesystem = "bpool";
                      label = "${group}.${name}";
                      extraFormatArgs = [ "--discard" ];
                    };
                  };
                };
              };
            }
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
    }
  ]);
}
