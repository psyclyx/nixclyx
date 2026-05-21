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
    protectDataset = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        zfs-dataset entity name whose encryption root is bound by this
        clevis pin. The dataset must declare encryption (asserted).
        Mutually exclusive with protectLuksDevice.
      '';
    };
    protectLuksDevice = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Path to a LUKS device (e.g. /dev/disk/by-partlabel/cryptroot)
        on the producer that this clevis pin wraps. Mutually
        exclusive with protectDataset.
      '';
    };
  };

  attrs =
    name: entity: top:
    let
      b = entity.clevis-binding;
      target =
        if b.protectDataset != null then "dataset:${b.protectDataset}"
        else if b.protectLuksDevice != null then "luks:${b.protectLuksDevice}"
        else "<unbound>";
      datasetEnt =
        if b.protectDataset == null then null
        else top.entities.${b.protectDataset} or null;
      tangEnts = map (n: top.entities.${n} or null) b.tangs;
      tangUrls = lib.filter (u: u != null) (map (e: if e == null then null else e.attrs.url or null) tangEnts);
    in
    {
      label = "${toString (builtins.length b.tangs)} tang(s) → ${target}";
      producer = if datasetEnt == null then null else datasetEnt.attrs.producer or null;
      inherit tangUrls;
    };

  assertions =
    name: entity: top:
    let
      b = entity.clevis-binding;
      datasetEnt =
        if b.protectDataset == null then null
        else top.entities.${b.protectDataset} or null;
    in
    [
      {
        assertion = b.tangs != [ ];
        message = "clevis-binding '${name}' requires at least one tang";
      }
      {
        assertion =
          (b.protectDataset != null) != (b.protectLuksDevice != null);
        message = "clevis-binding '${name}' requires exactly one of protectDataset / protectLuksDevice";
      }
      {
        assertion = b.protectDataset == null
          || (top.entities ? ${b.protectDataset} && top.entities.${b.protectDataset}.type == "zfs-dataset");
        message = "clevis-binding '${name}' protectDataset '${toString b.protectDataset}' must be a zfs-dataset entity";
      }
      {
        assertion = datasetEnt == null || datasetEnt.zfs-dataset.encryption != null;
        message = "clevis-binding '${name}' protectDataset '${toString b.protectDataset}' must be an encryption root (have encryption set)";
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
