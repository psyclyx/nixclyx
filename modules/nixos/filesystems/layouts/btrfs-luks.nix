# Btrfs-on-LUKS subvolume layout.
#
# Standard pattern: LUKS container → btrfs with named subvolumes,
# separate boot partition, optional swap.
{
  path = ["psyclyx" "nixos" "filesystems" "layouts" "btrfs-luks"];
  description = "Btrfs-on-LUKS subvolume layout";
  options = { lib, ... }: {
    luksUUID = lib.mkOption {
      type = lib.types.str;
      description = "UUID of the LUKS container.";
    };
    luksName = lib.mkOption {
      type = lib.types.str;
      default = "crypted";
      description = "Name for the opened LUKS device.";
    };
    fsUUID = lib.mkOption {
      type = lib.types.str;
      description = "UUID of the btrfs filesystem inside LUKS.";
    };
    bootUUID = lib.mkOption {
      type = lib.types.str;
      description = "UUID of the EFI boot partition.";
    };
    swapUUID = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "UUID of swap partition (null to disable).";
    };
    subvolumes = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "Mount point → btrfs subvolume name mapping.";
      example = {
        "/" = "@";
        "/home" = "@home";
        "/nix" = "@nix";
      };
    };
  };
  config = { cfg, lib, ... }: let
    fsDevice = "/dev/disk/by-uuid/${cfg.fsUUID}";
  in {
    boot.initrd.luks.devices.${cfg.luksName} = {
      device = "/dev/disk/by-uuid/${cfg.luksUUID}";
    };

    fileSystems = lib.mapAttrs (_mountpoint: subvol: {
      device = fsDevice;
      fsType = "btrfs";
      options = ["subvol=${subvol}"];
    }) cfg.subvolumes // {
      "/boot" = {
        device = "/dev/disk/by-uuid/${cfg.bootUUID}";
        fsType = "vfat";
        options = ["fmask=0077" "dmask=0077"];
      };
    };

    swapDevices = lib.optional (cfg.swapUUID != null)
      { device = "/dev/disk/by-uuid/${cfg.swapUUID}"; };
  };
}
