# Fleet storage topology — pools, datasets, encryption roots, clevis
# bindings. Today's only producer is lab-4's `tank`; the schema is
# already shaped for additional pools on other hosts (declare another
# zfs-pool referencing its producer, add datasets, point consumers).
let
  # Lab-4's tank: 8x800 GB SSDs as a single raidz2 vdev. Same set the
  # current disko block configures; lifted here so the storage
  # projection has a single source of truth.
  tankDisks = [
    { id = "wwn-0x55cd2e404c258d01"; note = "sda LK0800GEYMU"; }
    { id = "wwn-0x55cd2e404c3a6735"; note = "sdb LK0800GEYMU"; }
    { id = "wwn-0x55cd2e404c157a56"; note = "sdc INTEL SSDSC2BX800G4"; }
    { id = "wwn-0x55cd2e404c2594de"; note = "sdd LK0800GEYMU"; }
    { id = "wwn-0x55cd2e404c25f5ea"; note = "sde LK0800GEYMU"; }
    { id = "wwn-0x5000cca04fb8e258"; note = "sdf HUSMM1680ASS204"; }
    { id = "wwn-0x5000cca02b04a3ec"; note = "sdg MO0800JDVEV"; }
    { id = "wwn-0x5000cca02b11aab0"; note = "sdh MO0800JDVEV"; }
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
          vdevs = [
            { mode = "raidz2"; disks = tankDisks; }
          ];
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
  };
}
