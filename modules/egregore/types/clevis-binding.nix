# Entity type: clevis binding.
#
# Binds an encrypted ZFS pool (or LUKS device) to one or more tang
# servers. The storage projection reads this to emit (a) the
# in-initrd clevis client config on the consumer side and (b) the
# first-boot `clevis luks bind` / ZFS-key-wrap one-shot on the
# producer side. Multiple tangs are supported up-front so adding
# redundancy is just appending to the list, with no schema change.
{
  lib,
  egregorLib,
  config,
  ...
}:
egregorLib.mkType {
  name = "clevis-binding";
  topConfig = config;
  description = "Binding between an encrypted store (ZFS pool / LUKS) and tang servers.";

  options = {
    tangs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Tang-server entity names this binding trusts. At least one
        required (asserted). With more than one, the projection
        configures a threshold scheme (any-one-of by default).
      '';
    };
    threshold = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = ''
        Minimum number of tangs that must respond to unlock. 1 = any-
        one-of (default; cheapest redundancy). N = all-of for N tangs.
      '';
    };
    protectPool = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        zfs-pool entity name whose encryption root is bound by this
        clevis pin. Mutually exclusive with protectLuksDevice.
      '';
    };
    protectLuksDevice = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Path to a LUKS device (e.g. /dev/disk/by-partlabel/cryptroot)
        on the producer that this clevis pin wraps. Mutually
        exclusive with protectPool.
      '';
    };
  };

  attrs =
    name: entity: top:
    let
      b = entity.clevis-binding;
      target =
        if b.protectPool != null then "pool:${b.protectPool}"
        else if b.protectLuksDevice != null then "luks:${b.protectLuksDevice}"
        else "<unbound>";
      poolEnt =
        if b.protectPool == null then null
        else top.entities.${b.protectPool} or null;
      tangEnts = map (n: top.entities.${n} or null) b.tangs;
      tangUrls = lib.filter (u: u != null) (map (e: if e == null then null else e.attrs.url or null) tangEnts);
    in
    {
      label = "${toString (builtins.length b.tangs)} tang(s) → ${target}";
      producer = if poolEnt == null then null else poolEnt.refs.host or null;
      inherit tangUrls;
    };

  assertions =
    name: entity: top:
    let
      b = entity.clevis-binding;
    in
    [
      {
        assertion = b.tangs != [ ];
        message = "clevis-binding '${name}' requires at least one tang";
      }
      {
        assertion =
          (b.protectPool != null) != (b.protectLuksDevice != null);
        message = "clevis-binding '${name}' requires exactly one of protectPool / protectLuksDevice";
      }
      {
        assertion = b.protectPool == null
          || (top.entities ? ${b.protectPool} && top.entities.${b.protectPool}.type == "zfs-pool");
        message = "clevis-binding '${name}' protectPool '${toString b.protectPool}' must be a zfs-pool entity";
      }
      {
        assertion = b.threshold >= 1 && b.threshold <= builtins.length b.tangs;
        message = "clevis-binding '${name}' threshold ${toString b.threshold} out of range (1..${toString (builtins.length b.tangs)})";
      }
    ]
    ++ map (tn: {
      assertion = top.entities ? ${tn} && top.entities.${tn}.type == "tang-server";
      message = "clevis-binding '${name}' tang '${tn}' is not a tang-server entity";
    }) b.tangs;
}
