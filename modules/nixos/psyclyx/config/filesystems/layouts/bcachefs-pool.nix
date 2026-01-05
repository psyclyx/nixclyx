{ config, lib, ... }:
let
  cfg = config.psyclyx.filesystems.layouts.bcachefs-pool;
in
{
  options = {
    psyclyx.filesystems.layouts.bcachefs-pool = {
      enable = lib.mkEnableOption "@psyclyx's bcachefs-pool disk layout";

      UUID = {
        root = lib.mkOption {
          type = lib.types.str;
          description = "external bcachefs FS UUID (`bcachefs show-superblock`)";
        };

        boot = lib.mkOption {
          type = lib.types.str;
          description = "boot partition UUID (`ls -lah /dev/disk/by-uuid`)";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    psyclyx.nixos.filesystems.bcachefs.enable = true;

    fileSystems = {
      "/" = {
        device = "/dev/disk/by-uuid/${cfg.UUID.root}";
        fsType = "bcachefs";
      };

      "/boot" = {
        device = "/dev/disk/by-uuid/${cfg.UUID.boot}";
        fsType = "vfat";
        options = [ "umask=0077" ];
      };
    };
  };

}
