{
  path = [
    "psyclyx"
    "nixos"
    "filesystems"
    "layouts"
    "bcachefs-subvols"
  ];
  description = "bcachefs subvolume layout";
  options =
    { lib, ... }:
    let
      subvolType = lib.types.submodule {
        options = {
          subdir = lib.mkOption {
            type = lib.types.str;
            description = "Path within the bcachefs filesystem.";
          };
          neededForBoot = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
        };
      };
    in
    {
      device = lib.mkOption {
        type = lib.types.str;
        description = "Root bcachefs device (fstab syntax: UUID=..., PARTLABEL=..., etc.).";
        example = "UUID=0b6d93c8-c6d3-4243-9413-25543a093c65";
      };
      bootDevice = lib.mkOption {
        type = lib.types.str;
        description = "EFI boot partition device (fstab syntax).";
        example = "PARTLABEL=nvme0-boot";
      };

      extraDeviceWants = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional device paths for multi-device pools (x-systemd.wants=).";
      };
      subvolumes = lib.mkOption {
        type = lib.types.attrsOf subvolType;
        description = "Mount point → subvolume mapping.";
      };
    };
  config =
    { cfg, lib, ... }:
    let
      wantOpts = map (d: "x-systemd.wants=${d}") cfg.extraDeviceWants;

      mkSubvolMount =
        _mountpoint: vol:
        {
          device = cfg.device;
          fsType = "bcachefs";
          options = wantOpts ++ [ "X-mount.subdir=${vol.subdir}" ];
        }
        // lib.optionalAttrs vol.neededForBoot { inherit (vol) neededForBoot; };
    in
    {
      fileSystems = lib.mapAttrs mkSubvolMount cfg.subvolumes // {
        "/boot" = {
          device = cfg.bootDevice;
          fsType = "vfat";
          options = [ "umask=0077" ];
        };
      };
    };
}
