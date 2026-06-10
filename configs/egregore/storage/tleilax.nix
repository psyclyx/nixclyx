# tleilax's ZFS layout: tank (3x SATA SSD raidz1) — general storage
# for the colo box.
#
# Pool was built by hand on 2026-06-09; the disko declaration here
# is descriptive (matches what's on disk) and used by the storage
# projection to wire the runtime mounts.
{
  gate = "always";
  config.entities = {
    # 3x 2 TB SATA SSDs as raidz1 (~3.5 TiB usable). General-purpose
    # storage for the colo box — nvme image backups today; future
    # blockchain workloads etc. live as sibling datasets.
    tleilax-tank-pool = {
      type = "zfs-pool";
      refs.host = "tleilax";
      zfs-pool = {
        name = "tank";
        topology = {
          vdevs = [
            { mode = "raidz1"; disks = [
                { id = "wwn-0x500a0751e88ef894"; note = "sda Crucial MX500 2TB"; }
                { id = "wwn-0x5002538f5510225e"; note = "sdc Samsung 870 EVO 2TB"; }
                { id = "wwn-0x5002538f551022ce"; note = "sdd Samsung 870 EVO 2TB"; }
            ]; }
          ];
          options.ashift = "12";
          options.autotrim = "on";
          rootFsOptions = {
            mountpoint = "none";
            compression = "zstd";
            atime = "off";
            xattr = "sa";
            acltype = "posixacl";
          };
        };
      };
    };

    # Catch-all backups dataset: nvme/laptop disk images, etc.
    # recordsize=1M because the typical inhabitant is a multi-GiB .zst
    # — fewer indirect blocks, better streaming throughput. No
    # encryption: these are dumps of disks we already control.
    tleilax-tank-backups = {
      type = "zfs-dataset";
      refs.pool = "tleilax-tank-pool";
      zfs-dataset = {
        path = "tank/backups";
        mountpoint = "/tank/backups";
        properties.recordsize = "1M";
      };
    };
  };
}
