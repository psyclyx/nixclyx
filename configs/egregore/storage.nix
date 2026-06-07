# Fleet storage topology — pools, datasets, encryption roots, clevis
# bindings. Today's only producer is lab-4's `tank`; the schema is
# already shaped for additional pools on other hosts (declare another
# zfs-pool referencing its producer, add datasets, point consumers).
let
  # Lab-4's SSDs: 8x ~800 GB. After the 2026 storage rework, 6 of them
  # form `tank` as 3 mirrors (VM iSCSI + nix-shared + per-host persist
  # — IOPS-bound), and the remaining 2 form `vault`'s special vdev
  # mirror (metadata + small blocks for the HDD pool).
  tankMirrors = [
    [ { id = "wwn-0x55cd2e404c157a56"; note = "sda INTEL SSDSC2BX800G4"; }
      { id = "wwn-0x55cd2e404c3a6735"; note = "sdb LK0800GEYMU"; } ]
    [ { id = "wwn-0x55cd2e404c258d01"; note = "sdc LK0800GEYMU"; }
      { id = "wwn-0x55cd2e404c2594de"; note = "sdd LK0800GEYMU"; } ]
    [ { id = "wwn-0x55cd2e404c25f5ea"; note = "sde LK0800GEYMU"; }
      { id = "wwn-0x5000cca04fb8e258"; note = "sdf HUSMM1680ASS204"; } ]
  ];

  # Vault's special vdev mirror — the leftover 2 SSDs. Attached
  # imperatively after pool create (the zfs-pool type doesn't model
  # vdev class yet; see migration runbook).
  vaultSpecialDisks = [
    { id = "wwn-0x5000cca02b04a3ec"; note = "sdg MO0800JDVEV"; }
    { id = "wwn-0x5000cca02b11aab0"; note = "sdh MO0800JDVEV"; }
  ];

  # Vault's data vdev: 6x 6 TB SAS HDDs as a single raidz2. ~22 TB
  # usable; takes the bulk/archive workload off tank.
  vaultDisks = [
    { id = "wwn-0x5000c5008689068f"; note = "sdk Seagate ST6000NM0195"; }
    { id = "wwn-0x5000c50086839fcb"; note = "sdl Seagate ST6000NM0195"; }
    { id = "wwn-0x5000cca2550365c0"; note = "sdm HGST HUS726060AL4210"; }
    { id = "wwn-0x5000c500d723e9a7"; note = "sdn OOS6000G"; }
    { id = "wwn-0x5000cca25509a5a4"; note = "sdo HGST HUS726060AL4210"; }
    { id = "wwn-0x5000c500ca85744f"; note = "sdp OOS6000G"; }
  ];

  mkLabPersistDataset = n: {
    type = "zfs-dataset";
    refs.pool = "tank-pool";
    zfs-dataset = {
      path = "tank/persist/lab-${toString n}";
      # lab-4 mounts its own /persist locally; everyone else's lives
      # under /srv/nfs/persist/ for NFS export.
      mountpoint =
        if n == 4 then "/persist"
        else "/srv/nfs/persist/lab-${toString n}";
      # lab-4's /persist is needed in stage-1 so preservation can
      # bind /etc/machine-id, /etc/ssh/* before systemd/sshd start.
      # The other lab-N persists are NFS-exported, not locally mounted
      # for boot use, so they don't need to be early.
      neededForBoot = n == 4;
    };
  };
in
{
  gate = "always";
  config.entities = {
    tank-pool = {
      type = "zfs-pool";
      refs.host = "lab-4";
      zfs-pool = {
        name = "tank";
        topology = {
          # 3 two-way mirrors. Mirrors instead of raidz2 because tank
          # serves random-IO workloads (iSCSI VM disks, NFS metadata,
          # per-host /persist) — mirrors give near-disk IOPS per vdev
          # and faster resilvers, at the cost of ~2.4 TB usable vs.
          # the old raidz2-of-8's ~4 TB. Capacity for bulk lives on
          # vault now.
          vdevs = map (m: { mode = "mirror"; disks = m; }) tankMirrors;
          rootFsOptions = {
            canmount = "off";
            mountpoint = "none";
            compression = "zstd";
            atime = "off";
            xattr = "sa";
            acltype = "posixacl";
          };
        };
      };
    };

    # Plaintext datasets — closure store (reproducible, no secrets;
    # NFS-shared to lab-1..3) and ephemeral scratch.
    tank-nix-shared = {
      type = "zfs-dataset";
      refs.pool = "tank-pool";
      zfs-dataset = {
        path = "tank/nix-shared";
        # Mountpoint on the producer (lab-4). With lab-4 also using
        # the lab-loader, /nix lives here too — no overlay-fs squashfs
        # /nix, one persistent store shared with lab-1..3 over NFS.
        mountpoint = "/nix";
        neededForBoot = true;
      };
    };
    tank-scratch = {
      type = "zfs-dataset";
      refs.pool = "tank-pool";
      zfs-dataset = { path = "tank/scratch"; mountpoint = null; };
    };

    # Encrypted parent for per-host /persist. Children inherit the key.
    tank-persist = {
      type = "zfs-dataset";
      refs.pool = "tank-pool";
      zfs-dataset = {
        path = "tank/persist";
        mountpoint = null;
        encryption = { keyformat = "passphrase"; keylocation = "prompt"; };
      };
    };
    tank-persist-lab-1 = mkLabPersistDataset 1;
    tank-persist-lab-2 = mkLabPersistDataset 2;
    tank-persist-lab-3 = mkLabPersistDataset 3;
    tank-persist-lab-4 = mkLabPersistDataset 4;

    # Encrypted parent for VM disk zvols. canmount=off because nothing
    # should ever mount this dataset itself; the children (declared as
    # `lun` entities) live under it.
    tank-luns = {
      type = "zfs-dataset";
      refs.pool = "tank-pool";
      zfs-dataset = {
        path = "tank/luns";
        mountpoint = null;
        properties.canmount = "off";
        encryption = { keyformat = "passphrase"; keylocation = "prompt"; };
      };
    };

    # Lab-4's vault: 6x 6 TB SAS HDDs as a single raidz2, ~22 TB
    # usable. Bulk capacity tier — archives, snapshot replication
    # targets, future SeaweedFS volumes. A 2-way SSD special vdev
    # mirror absorbs metadata and small blocks (special_small_blocks
    # = 64K below); it's attached imperatively after pool create
    # because the zfs-pool type doesn't model vdev class yet. The
    # disks are listed in vaultSpecialDisks above for documentation.
    vault-pool = {
      type = "zfs-pool";
      refs.host = "lab-4";
      zfs-pool = {
        name = "vault";
        topology = {
          vdevs = [
            { mode = "raidz2"; disks = vaultDisks; }
          ];
          options.ashift = "12";
          rootFsOptions = {
            canmount = "off";
            mountpoint = "none";
            compression = "zstd";
            atime = "off";
            xattr = "sa";
            acltype = "posixacl";
            # 1 MiB recordsize keeps large-file streams off the HDDs'
            # IOPS budget (each record is one seek). Datasets that
            # want different (e.g. a future pg replication target)
            # override per-dataset.
            recordsize = "1M";
            # Redirect <= 64 KiB records and all metadata to the
            # special vdev. With ~745 GiB of SSD mirror, that's
            # plenty of headroom (the metadata-only footprint of a
            # 22 TB pool is < 100 GiB).
            special_small_blocks = "65536";
          };
        };
      };
    };

    # Archive parent — canmount=off, just a structural container.
    vault-archive = {
      type = "zfs-dataset";
      refs.pool = "vault-pool";
      zfs-dataset = {
        path = "vault/archive";
        mountpoint = null;
        properties.canmount = "off";
      };
    };

    # Recovered rpool from the old lab-1 install (Mar 2026). Raw-sent
    # encrypted from the disk-shelf import; the original install's
    # passphrase still unlocks it. Not clevis-bound — it's a
    # cold-storage archive, not a runtime mount.
    vault-archive-lab-1-rpool = {
      type = "zfs-dataset";
      refs.pool = "vault-pool";
      zfs-dataset = {
        path = "vault/archive/lab-1-rpool";
        mountpoint = null;
        encryption = { keyformat = "passphrase"; keylocation = "prompt"; };
      };
    };

    # Sigil's rpool: workstation pool, single nvme partition. Bootstrapped
    # imperatively (the disko translation in topology/storage.nix assumes
    # whole-disk GPT pools, which doesn't fit sigil's EFI+swap+zfs layout);
    # the topology block is documentation, and the storage projection is
    # NOT enabled on sigil yet — the runtime mounts here are descriptive
    # of what was created by hand, not actively wired into NixOS.
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
    # harder). Same descriptive-only caveat as sigil-rpool above —
    # the topology block documents what's on the disk; the actual
    # NixOS mounts live in `hosts/nixos/sigil/filesystems.nix`.
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
