# Stand-alone NFS exports — paths NOT backed by a zfs-dataset entity.
#
# ZFS-dataset-backed exports (the shared nix store, per-host /persist
# dirs) are derived by topology/storage.nix from the zfs-dataset
# entities + host refs.{nixDataset,persistDataset}. Anything else
# (plain directory exports) lives as an explicit nfs-export entity
# in its own config file.
{
  gate = "always";
  config.entities = { };
}
