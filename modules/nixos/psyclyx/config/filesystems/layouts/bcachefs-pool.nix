{ config, lib, ... }:
let
  cfg = config.psyclyx.filesystems.layouts.bcachefs-pool;
in
{
  options = {
    # TODO: Not the best abstraction, some sort of simpler wrapper around
    # fileSystems with a spot to compose bcachefs-specific stuff would be nicer
    psyclyx.filesystems.layouts.bcachefs-pool = {
      enable = lib.mkEnableOption "@psyclyx's bcachefs-pool disk layout";
      wants = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "list of devices to weakly depend on via x-systemd.wants";
        example = [
          "/dev/disk/by-id/foo"
          "/dev/disk/by-id/bar"
        ];
        default = [ ];
      };

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
        device = "UUID=${cfg.UUID.root}";
        fsType = "bcachefs";
        options = builtins.map (x: "x-systemd.wants=${x}") cfg.wants;
      };

      "/boot" = {
        device = "UUID=${cfg.UUID.boot}";
        fsType = "vfat";
        options = [ "umask=0077" ];
      };
    };
  };

}
