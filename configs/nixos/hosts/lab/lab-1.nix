{ lib, ... }:
let
  inherit (lib) genAttrs;

  disks = {
    "sda" = "scsi-35000c50085e87d1b";
    "sdb" = "scsi-35000c50085e8525b";
    "sdc" = "scsi-35000c500ca85744f";
    "sdd" = "scsi-35000c500d723e9a7";
  };

  idDevice = id: "/dev/disk/by-id/${id}";

in
{
  imports = [
    ./common.nix
  ];

  config = {
    networking = {
      hostName = "lab-1";
      hostId = "433b22ca";
    };

    boot.supportedFilesystems = [ "zfs" ];

    boot.loader.zfsbootmenu = {
      enable = true;
      bootfs = "rpool/nixos";
    };

    boot.zfs.extraPools = [ "rpool" ];

    disko.devices = {
      disk = lib.mapAttrs (_: id: {
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
      }) disks;

      zpool = {
        rpool = {
          type = "zpool";
          mode = "mirror";
          datasets = {
            "nixos" = {
              type = "zfs_fs";
              mountpoint = "/";
              options = {
                mountpoint = "/";
                "com.sun:auto-snapshot" = "false";
                compression = "zstd";
              };
            };

          };
        };
      };
    };

  };
}
