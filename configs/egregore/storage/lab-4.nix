# lab-4's ZFS layout: tank (3 SSD mirrors) + vault (HDD raidz2 with
# SSD special vdev).
let
  # 8x ~800 GB SSDs. After the 2026 storage rework, 6 form `tank` as
  # 3 mirrors (VM iSCSI + nix-shared + per-host persist — IOPS-bound)
  # and the remaining 2 form `vault`'s special vdev mirror (metadata
  # + small blocks for the HDD pool).
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
        # Mountpoint on the producer (lab-4). lab-4 mounts it locally;
        # lab-1..3 NFS-mount the same dataset — one persistent store
        # shared across the lab.
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
  };
}
