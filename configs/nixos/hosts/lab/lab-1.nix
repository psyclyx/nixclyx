{ lib, ... }:
let
  inherit (lib) genAttrs;

  disks = [
    "scsi-35000c50085e87d1b"
    "scsi-35000c50085e8525b"
    "scsi-35000c500ca85744f"
    "scsi-35000c500d723e9a7"
  ];

  idDevice = id: "/dev/disk/by-id/${id}";

in
{
  imports = [ ./common.nix ];

  config = {
    networking = {
      hostName = "lab-1";
      hostId = "433b22ca";
    };

    boot.supportedFilesystems = [ "zfs" ];
    boot.loader.zfsbootmenu = {
      enable = true;
    };
    boot.zfs.extraPools = [ "rpool" ];

    disko.devices = {
      disk = genAttrs disks (id: {
        type = "disk";
        device = idDevice id;
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "rpool";
              };
            };
          };
        };
      });

      zpool = {
        rpool = {
          type = "zpool";
          rootFsOptions = {
            compression = "lz4";
            "com.sun:auto-snapshot" = "false";
          };
          datasets = {
            root = {
              type = "zfs_fs";
              mountpoint = "/";
            };
          };
        };
      };
    };

  };
}
