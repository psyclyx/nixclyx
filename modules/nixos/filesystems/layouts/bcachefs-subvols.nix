# bcachefs subvolume layout using X-mount.subdir.
#
# Standard ephemeral-root pattern: root/@blank + root/@live snapshots,
# persistent /nix, /persist, /var/log, /home/*, /boot.
{
  path = ["psyclyx" "nixos" "filesystems" "layouts" "bcachefs-subvols"];
  description = "bcachefs subvolume layout (partlabel-based)";
  options = { lib, ... }: let
    subvolType = lib.types.submodule {
      options = {
        subdir = lib.mkOption {
          type = lib.types.str;
          description = "Path within bcachefs (X-mount.subdir value).";
        };
        neededForBoot = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
      };
    };
  in {
    rootPartlabel = lib.mkOption {
      type = lib.types.str;
      description = "Partlabel for the bcachefs root partition.";
      example = "nvme0-root";
    };
    bootPartlabel = lib.mkOption {
      type = lib.types.str;
      description = "Partlabel for the EFI boot partition.";
      example = "nvme0-boot";
    };
    swapPartlabel = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Partlabel for swap partition (null to disable).";
    };
    subvolumes = lib.mkOption {
      type = lib.types.attrsOf subvolType;
      description = "Mount point → subvolume mapping.";
      example = {
        "/" = { subdir = "subvolumes/root/@live"; };
        "/nix" = { subdir = "subvolumes/nix/@live"; neededForBoot = true; };
      };
    };
  };
  config = { cfg, lib, ... }: let
    rootDevice = "/dev/disk/by-partlabel/${cfg.rootPartlabel}";
  in {
    fileSystems = lib.mapAttrs (_mountpoint: vol: {
      device = rootDevice;
      fsType = "bcachefs";
      options = ["X-mount.subdir=${vol.subdir}"];
      inherit (vol) neededForBoot;
    }) cfg.subvolumes // {
      "/boot" = {
        device = "/dev/disk/by-partlabel/${cfg.bootPartlabel}";
        fsType = "vfat";
        options = ["umask=0077"];
      };
    };

    swapDevices = lib.optional (cfg.swapPartlabel != null)
      { device = "/dev/disk/by-partlabel/${cfg.swapPartlabel}"; };
  };
}
