{
  path = ["psyclyx" "nixos" "filesystems" "zfs"];
  description = "ZFS filesystem support";

  # pam.homes: every pam_zfs_key instance on the host, one per homes
  # prefix, all generated the same way. nixpkgs' own zfs_key rules handle
  # a single `homes=`; they're switched off here rather than kept for the
  # first prefix, so there is one path for "unlock <prefix>/<user> at
  # login", not a stock path plus an extras path. security.pam.zfs.enable
  # stays on: it's the per-service `zfs` default (the gate used below),
  # and polkit keys /dev/zfs access off it.
  #
  # Lives in an import because it extends nixpkgs' security.pam.services
  # submodule type — the only way to touch "every zfs service" without
  # reading security.pam.services to define it.
  #
  # Each instance sits where the stock rule would (so it sees the same
  # PAM_AUTHTOK) with its own `homes=` and its own `runstatedir=`:
  # pam_zfs_key keeps a per-uid session counter there, and instances
  # sharing one would count each other's opens and never unload on
  # logout. Each session instance gets its own systemd-user skip, because
  # a skip only jumps over the one rule after it.
  imports = [
    ({config, lib, ...}: let
      zcfg = config.psyclyx.nixos.filesystems.zfs;
      pcfg = config.security.pam.zfs;
      enabled = zcfg.enable && zcfg.pam.homes != [];
      zfsKey = "${config.boot.zfs.package}/lib/security/pam_zfs_key.so";
      succeedIf = "${config.security.pam.package}/lib/security/pam_succeed_if.so";
      slug = prefix: lib.replaceStrings ["/"] ["-"] prefix;
      settingsFor = prefix: {
        homes = prefix;
        runstatedir = "/run/pam_zfs_key-${slug prefix}";
        mount_recursively = pcfg.mountRecursively;
      };
      indexed = lib.imap0 (i: prefix: {inherit i prefix;}) zcfg.pam.homes;
    in {
      options.security.pam.services = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule ({config, ...}: let
          # Services with useDefaultRules = false (gdm-autologin, …) bring
          # their own stack and never had the stock rules. Within default
          # stacks the stock rule still isn't in every stage (auth only
          # carries it with unixAuth or homed), so disabling it has to
          # tolerate its absence: `stub` defines it at the lowest priority,
          # which only takes effect where nixpkgs didn't define it, and
          # leaves a disabled rule with order 0. Real stock rules are
          # auto-ordered from 10100 up, so `order > 0` is "the stock rule
          # is here". Probing values rather than shaping the attrset on
          # them is what keeps this from recursing on `rules`.
          stub = module: {
            enable = lib.mkForce false;
            order = lib.mkOverride 1500 0;
            control = lib.mkOverride 1500 "optional";
            modulePath = lib.mkOverride 1500 module;
          };
          at = stage: config.rules.${stage}.zfs_key.order;
          has = stage: at stage > 0;
          perPrefix = f: lib.listToAttrs (lib.concatMap f indexed);
        in {
          config.rules = lib.mkIf (enabled && config.zfs && config.useDefaultRules) {
            auth = {zfs_key = stub zfsKey;} // perPrefix ({i, prefix}: [
              (lib.nameValuePair "zfs_key-${slug prefix}" {
                enable = has "auth";
                order = at "auth" + 10 * i;
                control = "optional";
                modulePath = zfsKey;
                settings = settingsFor prefix;
              })
            ]);
            password = {zfs_key = stub zfsKey;} // perPrefix ({i, prefix}: [
              (lib.nameValuePair "zfs_key-${slug prefix}" {
                enable = has "password";
                order = at "password" + 10 * i;
                control = "optional";
                modulePath = zfsKey;
                settings = settingsFor prefix;
              })
            ]);
            session = {
              zfs_key = stub zfsKey;
              zfs_key-skip-systemd = stub succeedIf;
            } // perPrefix ({i, prefix}: [
              (lib.nameValuePair "zfs_key-${slug prefix}-skip-systemd" {
                enable = has "session";
                order = at "session" + 20 * i;
                control = "[success=1 default=ignore]";
                modulePath = succeedIf;
                args = ["service" "=" "systemd-user"];
              })
              (lib.nameValuePair "zfs_key-${slug prefix}" {
                enable = has "session";
                order = at "session" + 20 * i + 10;
                control = "optional";
                modulePath = zfsKey;
                settings = settingsFor prefix // {nounmount = pcfg.noUnmount;};
              })
            ]);
          };
        }));
      };

      config = lib.mkIf enabled {
        security.pam.zfs.enable = true;
      };
    })
  ];
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

    pam.homes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["rpool/home" "altpool/home"];
      description = ''
        Homes prefixes whose `<prefix>/<user>` dataset pam_zfs_key unlocks
        with the login password at login (and mounts, if it has a
        mountpoint). Each dataset's passphrase must equal the login password.
        Non-empty turns on security.pam.zfs and replaces its stock rules, so
        `security.pam.zfs.homes` is ignored; `noUnmount` and
        `mountRecursively` there still apply to every prefix.
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
