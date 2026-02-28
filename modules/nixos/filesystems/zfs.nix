{
  path = ["psyclyx" "nixos" "filesystems" "zfs"];
  description = "ZFS filesystem support";
  options = {lib, ...}: {
    hostId = lib.mkOption {
      type = lib.types.str;
      description = "8-character hex string for networking.hostId (required by ZFS)";
    };

    pools = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["rpool"];
      description = "ZFS pool names to request encryption credentials for";
    };

    encryption.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether pools use native ZFS encryption (prompts for passphrase in initrd)";
    };

    scrub = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable periodic ZFS scrubs";
      };
      interval = lib.mkOption {
        type = lib.types.str;
        default = "monthly";
        description = "Scrub interval (systemd calendar expression)";
      };
    };

    trim.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable periodic ZFS TRIM";
    };

    arc = {
      maxBytes = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        description = "Maximum ARC size in bytes (null = ZFS default, ~50% RAM)";
      };
      minBytes = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        description = "Minimum ARC size in bytes (null = ZFS default)";
      };
    };
  };

  config = {cfg, lib, ...}: {
    boot.supportedFilesystems = ["zfs"];
    boot.zfs.forceImportRoot = false;
    boot.zfs.requestEncryptionCredentials = lib.mkIf cfg.encryption.enable cfg.pools;

    # Disable the default 90s timeout on ZFS import services in initrd so the
    # encryption passphrase prompt doesn't time out and drop to emergency mode.
    # See: https://github.com/NixOS/nixpkgs/issues/250003
    boot.initrd.systemd.services = lib.mkIf cfg.encryption.enable (
      lib.listToAttrs (map (pool: lib.nameValuePair "zfs-import-${pool}" {
        serviceConfig.TimeoutStartSec = "infinity";
      }) cfg.pools)
    );

    networking.hostId = cfg.hostId;

    boot.kernelParams =
      ["nohibernate"]
      ++ lib.optional (cfg.arc.maxBytes != null) "zfs.zfs_arc_max=${toString cfg.arc.maxBytes}"
      ++ lib.optional (cfg.arc.minBytes != null) "zfs.zfs_arc_min=${toString cfg.arc.minBytes}"
      # Start async write flushing earlier (10% vs 30%) for smoother write latency
      ++ ["zfs.zfs_vdev_async_write_active_min_dirty_percent=10"];

    services.zfs.autoScrub = lib.mkIf cfg.scrub.enable {
      enable = true;
      interval = cfg.scrub.interval;
    };

    services.zfs.trim.enable = cfg.trim.enable;
  };
}
