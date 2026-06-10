# sigil's ZFS layout: rpool (OS + home, on NVMe) + bulkpool (backups
# on spinner) + scratchpool (ephemeral builds, on SSD).
#
# Bootstrapped imperatively (the disko translation in derived/
# storage.nix assumes whole-disk GPT pools, which doesn't fit sigil's
# EFI+swap+zfs layout); the topology blocks here are documentation,
# and the storage projection is NOT enabled on sigil yet — the runtime
# mounts here are descriptive of what was created by hand, not
# actively wired into NixOS.
{
  gate = "always";
  config.entities = {
    sigil-rpool = {
      type = "zfs-pool";
      refs.host = "sigil";
      zfs-pool = {
        name = "rpool";
        topology = {
          options.ashift = "12";
          rootFsOptions = {
            mountpoint = "none";
            compression = "zstd-3";
            atime = "off";
            xattr = "sa";
            acltype = "posixacl";
          };
        };
      };
    };

    # /nix: plaintext (reproducible store, no secrets — encrypting it
    # would just add a boot prompt for no real gain, matching the
    # tank-nix-shared rationale).
    sigil-nix = {
      type = "zfs-dataset";
      refs.pool = "sigil-rpool";
      zfs-dataset = {
        path = "rpool/nix";
        mountpoint = "/nix";
        neededForBoot = true;
      };
    };

    # /var/log: plaintext, broken out so log volume / retention is
    # independent of the impermanence-rolled root. Matches the bcachefs
    # `subvolumes/log` layout that's currently live. neededForBoot=true
    # so journald has a real /var/log before it starts.
    sigil-log = {
      type = "zfs-dataset";
      refs.pool = "sigil-rpool";
      zfs-dataset = {
        path = "rpool/log";
        mountpoint = "/var/log";
        neededForBoot = true;
      };
    };

    # /persist: encrypted root, passphrase at boot. Holds the impermanence-
    # persisted state (machine-id, host keys, shadow.psyc, etc.).
    sigil-persist = {
      type = "zfs-dataset";
      refs.pool = "sigil-rpool";
      zfs-dataset = {
        path = "rpool/persist";
        mountpoint = "/persist";
        neededForBoot = true;
        encryption = { keyformat = "passphrase"; keylocation = "prompt"; };
      };
    };

    # /home container: unencrypted, canmount=off. Each user dataset
    # underneath is its own independent encryption root with its own
    # passphrase (matched to the user's login password for pam_zfs_key
    # auto-unlock at session start).
    sigil-home = {
      type = "zfs-dataset";
      refs.pool = "sigil-rpool";
      zfs-dataset = {
        path = "rpool/home";
        mountpoint = null;
        properties.canmount = "off";
      };
    };

    sigil-home-psyc = {
      type = "zfs-dataset";
      refs.pool = "sigil-rpool";
      zfs-dataset = {
        path = "rpool/home/psyc";
        mountpoint = "/home/psyc";
        # canmount stays at the default `on`. pam_zfs_key.so refuses
        # to mount datasets with canmount != on, so we accept the
        # cost: at boot, `zfs mount -a` tries this dataset, sees the
        # key isn't loaded, and logs a one-line failure. pam_zfs_key
        # then mounts it at login.
        encryption = { keyformat = "passphrase"; keylocation = "prompt"; };
      };
    };

    # root's home: plaintext (no PAM hook for root, and root's home
    # typically has nothing worth an extra boot prompt over). Nested
    # under rpool/home rather than rpool/root so home datasets live
    # together; the mount path stays at the POSIX /root convention.
    sigil-home-root = {
      type = "zfs-dataset";
      refs.pool = "sigil-rpool";
      zfs-dataset = {
        path = "rpool/home/root";
        mountpoint = "/root";
      };
    };

    # Sigil's bulkpool: single 4 TB SAS spinner. Backup tier: holds
    # the pre-rollback boot history and replicated home snapshots.
    # Unencrypted (raw sends from the encrypted source datasets land
    # encrypted on this side anyway, so plaintext-ness here doesn't
    # leak user data; boot-history captures rolled-back /, which by
    # construction has no secrets — preservation routes those to
    # /persist on rpool).
    sigil-bulkpool = {
      type = "zfs-pool";
      refs.host = "sigil";
      zfs-pool = {
        name = "bulkpool";
        topology = {
          # 4k physical sectors on the ST4000NM0035 (4Kn / advanced
          # format). ashift=12 matches; lower values would waste IO
          # on read-modify-write cycles for any sub-4k block.
          options.ashift = "12";
          rootFsOptions = {
            mountpoint = "none";
            canmount = "off";
            # zstd at default level (3) — heavier than the on-disk
            # cost is recouped by HDD seek savings; higher levels
            # mostly burn CPU on already-mostly-incompressible
            # snapshot stream content.
            compression = "zstd";
            atime = "off";
            xattr = "sa";
            acltype = "posixacl";
          };
        };
      };
    };

    # Replication parent for syncoid-driven backups.
    sigil-bulkpool-backups = {
      type = "zfs-dataset";
      refs.pool = "sigil-bulkpool";
      zfs-dataset = {
        path = "bulkpool/backups";
        mountpoint = null;
        properties.canmount = "off";
      };
    };

    # Pre-rollback boot history. rpool/ROOT/nixos is rolled back to
    # @blank in stage-1; before that, the @blank → live delta is
    # sent here as @boot-<timestamp>. Lives on bulkpool so the
    # rollback wipes nothing useful and so root-pool failure still
    # leaves the history recoverable. See
    # `hosts/nixos/sigil/filesystems.nix` for the initrd send and
    # the post-boot retention prune.
    sigil-boot-history = {
      type = "zfs-dataset";
      refs.pool = "sigil-bulkpool";
      zfs-dataset = {
        path = "bulkpool/boot-history";
        # Created by `zfs receive` in stage-1; never mounted.
        mountpoint = null;
      };
    };

    # Replication target for rpool/home/psyc. Created on first
    # syncoid run via raw `zfs send -w`, which preserves the
    # source's native ZFS encryption — the backup is locked with
    # the same passphrase as the live home and never exists in
    # plaintext on the spinner.
    sigil-home-psyc-backup = {
      type = "zfs-dataset";
      refs.pool = "sigil-bulkpool";
      zfs-dataset = {
        path = "bulkpool/backups/home-psyc";
        mountpoint = null;
      };
    };

    # Sigil's scratchpool: single SSD, ephemeral working space.
    # Unencrypted (contents are reproducible / throwaway; encrypting
    # adds no real value and would just make boot-time mount ordering
    # harder).
    sigil-scratchpool = {
      type = "zfs-pool";
      refs.host = "sigil";
      zfs-pool = {
        name = "scratchpool";
        topology = {
          options.ashift = "12";
          rootFsOptions = {
            mountpoint = "none";
            compression = "zstd-3";
            atime = "off";
            xattr = "sa";
            acltype = "posixacl";
          };
        };
      };
    };

    # /tmp on ZFS. Ephemeral by convention, but living on a real
    # filesystem rather than tmpfs so large build trees don't have
    # to fit in RAM.
    sigil-tmp = {
      type = "zfs-dataset";
      refs.pool = "sigil-scratchpool";
      zfs-dataset = {
        path = "scratchpool/tmp";
        mountpoint = "/tmp";
      };
    };

    # /build: target dir for the nix-daemon's TMPDIR so build trees
    # land on the scratchpool instead of pressuring rpool. Separate
    # dataset from /tmp so build retention / quotas can diverge from
    # generic-temp policy if we ever want them to.
    sigil-build = {
      type = "zfs-dataset";
      refs.pool = "sigil-scratchpool";
      zfs-dataset = {
        path = "scratchpool/build";
        mountpoint = "/build";
      };
    };
  };
}
