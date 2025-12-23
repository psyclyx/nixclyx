{ config, lib, ... }:
let
  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    types
    ;

  cfg = config.psyclyx.filesystems.layouts.bcachefs-pool;
in
{
  options = {
    psyclyx.filesystems.layouts.bcachefs-pool = {
      enable = mkEnableOption "@psyclyx's bcachefs-pool disk layout";
      UUID = {
        root = mkOption {
          type = types.str;
          description = "external bcachefs FS UUID (`bcachefs show-superblock`)";
        };
        boot = mkOption {
          type = types.str;
          description = "boot partition UUID (`ls -lah /dev/disk/by-uuid`)";
        };
      };
    };
  };

  config = mkIf cfg.enable {
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
