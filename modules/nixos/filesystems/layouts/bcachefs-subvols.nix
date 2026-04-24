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
      baseMount = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Mount point for the raw bcachefs filesystem. When set,
          non-root subvolumes bind-mount from this path instead of
          using separate X-mount.subdir mounts.
        '';
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
        mountpoint: vol:
        let
          useBind = cfg.baseMount != null && mountpoint != "/";
          base = (
            if useBind then
              {
                device = "${cfg.baseMount}/${vol.subdir}";
                fsType = "none";
                options = [ "bind" ];
                depends = [ cfg.baseMount ];
              }
            else
              {
                device = cfg.device;
                fsType = "bcachefs";
                options = wantOpts ++ [ "X-mount.subdir=${vol.subdir}" ];
              }
          );
        in
        base // lib.optionalAttrs vol.neededForBoot { inherit (vol) neededForBoot; };

      baseMountEntry =
        if cfg.baseMount != null then
          {
            ${cfg.baseMount} = {
              device = cfg.device;
              fsType = "bcachefs";
              options = wantOpts;
              neededForBoot = true;
            };
          }
        else
          { };
    in
    {
      fileSystems =
        lib.mapAttrs mkSubvolMount cfg.subvolumes
        // {
          "/boot" = {
            device = cfg.bootDevice;
            fsType = "vfat";
            options = [ "umask=0077" ];
          };
        }
        // baseMountEntry;

    };
}
