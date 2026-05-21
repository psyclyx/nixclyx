# Entity type: ZFS dataset.
#
# A dataset in some zfs-pool. The producer is derived from the pool's
# producer (refs.host on the pool). Consumers — hosts that want this
# dataset's contents available — declare the relationship by referencing
# this dataset (e.g. host.boot.storage.{nix,persist} or host-level
# refs.<role>Dataset). The storage projection turns each consumer into
# either a local mount (if it owns the pool) or an NFS mount (otherwise,
# with the producer auto-exporting).
{
  lib,
  egregorLib,
  config,
  ...
}:
egregorLib.mkType {
  name = "zfs-dataset";
  topConfig = config;
  description = "A ZFS dataset within a zfs-pool, with a declared mountpoint.";

  options = {
    path = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Full dataset path including the pool prefix (e.g.
        "tank/nix-shared"). Required for real datasets (asserted
        non-empty); the empty default exists so non-dataset entities
        don't trip the option-without-default check.
      '';
    };
    mountpoint = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Mountpoint on the producer. Null = unmounted (e.g. parent
        datasets used only as encryption roots). Consumers may mount
        at different paths via their own consumption declarations.
      '';
    };
    properties = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Additional ZFS properties (compression, recordsize, atime, …)
        to apply at create-time. The storage projection passes these
        through to disko / zfs create.
      '';
    };
  };

  attrs =
    name: entity: top:
    let
      d = entity.zfs-dataset;
      pool = entity.refs.pool or null;
      poolEnt = if pool == null then null else top.entities.${pool} or null;
    in
    {
      label = d.path;
      poolName = if poolEnt == null then null else poolEnt.zfs-pool.name;
      producer = if poolEnt == null then null else poolEnt.refs.host or null;
    };

  assertions =
    name: entity: top:
    let
      d = entity.zfs-dataset;
      pool = entity.refs.pool or null;
    in
    [
      {
        assertion = d.path != "";
        message = "zfs-dataset '${name}' requires a non-empty path";
      }
      {
        assertion = pool != null;
        message = "zfs-dataset '${name}' requires refs.pool";
      }
      {
        assertion = pool == null || (top.entities ? ${pool} && top.entities.${pool}.type == "zfs-pool");
        message = "zfs-dataset '${name}' refs.pool '${toString pool}' must be a zfs-pool entity";
      }
    ];
}
