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
      description = ''
        Pool names imported in initrd — i.e. those backing a boot-critical
        mount. Used to lift the import timeout on their initrd units, so
        naming a pool with no initrd import unit fabricates an empty one.
        The complement is `dataPools`.
      '';
    };

    encryptionRoots = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      description = ''
        Pools or datasets to load encryption keys for during initrd. Naming a
        pool covers every encryption root under it; naming a dataset covers
        just that one, which is what you want when a pool holds roots that
        must stay locked until later (a home dataset unlocked by PAM at
        login, say).

        null falls back to `pools`, the common case where the whole boot pool
        is unlocked up front.
      '';
    };

    dataPools = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options.importTimeout = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              TimeoutStartSec for this pool's stage-2 import unit, or null for
              the upstream default. Set this to fail fast on hosts where the
              pool may legitimately not exist yet (first boot, pre-disko)
              rather than blocking multi-user.target for minutes.
            '';
          };
        }
      );
      default = {};
      description = ''
        Pools imported after boot rather than in initrd — those backing no
        boot-critical mount. Each gets a stage-2 `zfs-import-<pool>.service`,
        which this module pins to boot-time only (`restartIfChanged = false`).

        Those units are `Type=oneshot` + `RemainAfterExit=true`: their active
        state records "this pool is imported" and nothing more, so re-running
        one on a live system accomplishes nothing. Letting
        switch-to-configuration restart them on a ZFS version bump is actively
        harmful — the stop half propagates through the
        `Requires=zfs-import-<pool>.service` that every mount unit on the pool
        carries, and on into anything declaring `RequiresMountsFor=` on those
        mounts. Where a pool backs /tmp that reaches dbus-broker and
        local-fs.target, taking down sysinit.target, logind and the graphical
        session — including the shell running the rebuild, which leaves the
        system profile switched but activation never run.

        The rewritten import script takes effect at the next boot, alongside
        the kmod it was built against.
      '';
    };

    explicitMounts = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether mounts are owned by explicit `fileSystems` entries rather than
        by `zfs mount -a`. Takes `zfs-mount.service` out of the boot path so
        systemd's generated .mount units don't race it.
      '';
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

  config = {cfg, lib, ...}: let
    # The one place that knows how a pool name maps to an import unit name.
    # Everything configuring a pool import goes through this rather than
    # spelling the unit name out again.
    importUnits = settingsFor: pools:
      lib.listToAttrs (map (pool:
        lib.nameValuePair "zfs-import-${pool}" (settingsFor pool)
      ) pools);
  in {
    boot.supportedFilesystems = ["zfs"];
    boot.zfs.forceImportRoot = false;
    boot.zfs.requestEncryptionCredentials = lib.mkIf cfg.encryption.enable (
      if cfg.encryptionRoots == null then cfg.pools else cfg.encryptionRoots
    );

    # Disable the default 90s timeout on ZFS import services in initrd so the
    # encryption passphrase prompt doesn't time out and drop to emergency mode.
    # See: https://github.com/NixOS/nixpkgs/issues/250003
    boot.initrd.systemd.services = lib.mkIf cfg.encryption.enable (
      importUnits (_: { serviceConfig.TimeoutStartSec = "infinity"; }) cfg.pools
    );

    # Rationale on `dataPools`. restartIfChanged rather than stopIfChanged:
    # `systemctl restart` would also avoid the propagation, but there is no
    # reason to re-run a pool import on a running system at all.
    systemd.services = importUnits (pool:
      let spec = cfg.dataPools.${pool}; in
      { restartIfChanged = false; }
      // lib.optionalAttrs (spec.importTimeout != null) {
        serviceConfig.TimeoutStartSec = lib.mkDefault spec.importTimeout;
      }
    ) (lib.attrNames cfg.dataPools)
    // lib.optionalAttrs cfg.explicitMounts {
      zfs-mount.wantedBy = lib.mkForce [];
    };

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
