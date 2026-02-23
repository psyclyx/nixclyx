{
  path = ["psyclyx" "nixos" "filesystems" "layouts" "bcachefs-pool"];
  description = "@psyclyx's bcachefs-pool disk layout";
  options = {lib, ...}: {
    wants = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "list of devices to weakly depend on via x-systemd.wants";
      example = [
        "/dev/disk/by-id/foo"
        "/dev/disk/by-id/bar"
      ];
      default = [];
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
  config = {
    cfg,
    lib,
    ...
  }: {
    psyclyx.nixos.filesystems.bcachefs.enable = true;

    fileSystems = {
      "/" = {
        device = "UUID=${cfg.UUID.root}";
        fsType = "bcachefs";
        options = lib.mkIf (cfg.wants != []) (builtins.map (x: "x-systemd.wants=${x}") cfg.wants);
      };

      "/boot" = {
        device = "UUID=${cfg.UUID.boot}";
        fsType = "vfat";
        options = ["umask=0077"];
      };
    };
  };
}
