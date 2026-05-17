# Runtime-imported ZFS pool with declared dataset mounts.
#
# For hosts whose root + /nix come from somewhere else (PXE, ramdisk,
# or another disk), the pool exists only as runtime storage. Datasets
# get mounted at arbitrary paths the operator names; no assumption that
# any particular dataset holds the OS.
#
# Pool creation is out of scope — declare the pool layout with disko
# (or create it by hand). This module only declares the mount-time
# wiring + ZFS module config.
{
  path = ["psyclyx" "nixos" "filesystems" "zfs-runtime"];
  description = "Import a ZFS pool at boot and mount its datasets at runtime";

  options = {lib, ...}: {
    poolName = lib.mkOption {
      type = lib.types.str;
      description = "ZFS pool name to import.";
    };

    hostId = lib.mkOption {
      type = lib.types.str;
      description = "8-character hex string for networking.hostId.";
    };

    arc.maxBytes = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = "Maximum ARC size in bytes (null = ZFS default).";
    };

    datasets = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            mountpoint = lib.mkOption {
              type = lib.types.str;
              description = "Where to mount this dataset.";
            };
            options = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = ["zfsutil"];
            };
            neededForBoot = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                Whether the mount must happen before systemd considers
                the system "online". true for /persist (where machine-id
                etc. live), false for service data we can wait on.
              '';
            };
          };
        }
      );
      default = {};
      description = ''
        Datasets to mount at runtime, keyed by full dataset path
        (e.g. "<pool>/persist"). Encryption status is per-dataset and
        managed via zfs key-load (see filesystems/zfs.nix); this module
        only describes mount points.
      '';
    };
  };

  config = {cfg, lib, ...}: {
    psyclyx.nixos.filesystems = {
      zfs = {
        enable = true;
        hostId = cfg.hostId;
        pools = [ cfg.poolName ];
        arc.maxBytes = cfg.arc.maxBytes;
        # The runtime model loads encryption keys per-dataset post-boot
        # (operator or seal oracle), not via initrd passphrase prompts.
        encryption.enable = false;
      };
    };

    fileSystems = lib.mapAttrs' (dataset: spec:
      lib.nameValuePair spec.mountpoint {
        device = dataset;
        fsType = "zfs";
        options = spec.options
          ++ lib.optional (!spec.neededForBoot) "nofail"
          ++ lib.optional (!spec.neededForBoot) "x-systemd.device-timeout=10s";
        neededForBoot = spec.neededForBoot;
      }
    ) cfg.datasets;

    # As with the legacy zfs-pool layout, we manage mounts via explicit
    # fileSystems entries to avoid racing systemd's generated .mount
    # units against zfs-mount.service.
    systemd.services.zfs-mount.wantedBy = lib.mkForce [];

    # Fail-fast on first boot when the pool doesn't exist yet (pre-disko).
    # Default upstream timeout is several minutes and there's no point
    # blocking multi-user.target waiting for a pool that needs operator
    # action to create. Boot proceeds; bring the pool up and the import
    # service will succeed on next start (or restart manually).
    systemd.services."zfs-import-${cfg.poolName}".serviceConfig.TimeoutStartSec =
      lib.mkDefault "30s";
  };
}
