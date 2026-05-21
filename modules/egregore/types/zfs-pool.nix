# Entity type: ZFS pool.
#
# A ZFS pool lives on a single producer host (refs.host). Pool layout
# (vdev shape, member disks) is described as data; the storage
# projection lifts it into disko on the producer.
#
# Encryption is described per-dataset (see zfs-dataset.encryption), not
# at the pool level — a single pool can host multiple independent
# encryption roots. Key delivery (clevis-tang, passphrase prompt,
# fido2) is a separate concern: declare a clevis-binding entity
# referencing an encrypted dataset to wire up clevis.
{
  lib,
  egregorLib,
  config,
  ...
}:
egregorLib.mkType {
  name = "zfs-pool";
  topConfig = config;
  description = "A ZFS pool with topology and optional native encryption.";

  options = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Pool name as ZFS sees it (e.g. "tank"). Required for real
        pools (asserted non-empty); empty default exists so non-pool
        entities don't trip the option-without-default check.
      '';
    };
    topology = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        Pool topology as a free-form attrset, consumed by the storage
        projection when emitting disko config. Shape mirrors disko's
        `zpool.<name>.mode.topology` (vdev mode + member disks). Free-
        form here so the projection can pick its disko version without
        the type schema lagging upstream.
      '';
    };
  };

  attrs =
    name: entity: _top:
    let
      p = entity.zfs-pool;
    in
    {
      label = p.name;
      producer = entity.refs.host or null;
    };

  assertions =
    name: entity: top:
    let
      p = entity.zfs-pool;
      host = entity.refs.host or null;
    in
    [
      {
        assertion = p.name != "";
        message = "zfs-pool '${name}' requires a non-empty name";
      }
      {
        assertion = host != null;
        message = "zfs-pool '${name}' requires refs.host (the producer)";
      }
      {
        assertion = host == null || (top.entities ? ${host} && top.entities.${host}.type == "host");
        message = "zfs-pool '${name}' refs.host '${toString host}' must be a host entity";
      }
    ];
}
