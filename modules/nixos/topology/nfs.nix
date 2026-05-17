# Egregore → NFS projection.
#
# Reads `nfs-export` entities. For each:
#   - If this host is the producer: feed services.nfs-server.exports with
#     the export path and consumers' IPs (on the configured network).
#   - If this host is in `consumers` and `mountAt` is set: emit a
#     fileSystems entry that mounts the export at that path.
#
# Strictly a projection — no upstream service config beyond what's
# exposed by services.nfs-server and the kernel NFS client.
{config, lib, ...}: let
  cfg = config.psyclyx.nixos.topology.nfs;
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;
  me = eg.entities.${hostname} or null;
  enabled = cfg.enable && me != null;

  allExports = lib.filterAttrs (_: e: e.type == "nfs-export") eg.entities;

  # Producer-side: exports we host.
  myExports = lib.filterAttrs (_: e:
    (e.refs.producer or null) == hostname
  ) allExports;

  # Look up a consumer host's IP on the export's network.
  consumerIp = consumer: network:
    eg.entities.${consumer}.host.addresses.${network}.ipv4;

  mkServerExport = _expName: e: {
    path = e.nfs-export.path;
    clients = map (c: {
      address = consumerIp c e.nfs-export.network;
      readOnly = e.nfs-export.readOnly;
    }) e.nfs-export.consumers;
  };

  serverExports = lib.mapAttrsToList mkServerExport myExports;

  # Consumer-side: exports we mount.
  myMounts = lib.filterAttrs (_: e:
    e.nfs-export.mountAt != null
    && builtins.elem hostname e.nfs-export.consumers
  ) allExports;

  # Producer's IP on the export's network — that's the NFS server address.
  producerIp = e:
    eg.entities.${e.refs.producer}.host.addresses.${e.nfs-export.network}.ipv4;

  mkConsumerMount = _expName: e: {
    name = e.nfs-export.mountAt;
    value = {
      device = "${producerIp e}:${e.nfs-export.path}";
      fsType = "nfs";
      options = [ "_netdev" "nofail" "x-systemd.device-timeout=30s" ]
        ++ e.nfs-export.options;
    };
  };

  consumerFileSystems = lib.mapAttrs' mkConsumerMount myMounts;
in {
  options.psyclyx.nixos.topology.nfs = {
    enable = lib.mkEnableOption "project nfs-export entities into server config and consumer mounts";
  };

  config = lib.mkIf enabled {
    psyclyx.nixos.services.nfs-server = lib.mkIf (myExports != {}) {
      enable = true;
      exports = serverExports;
    };

    fileSystems = lib.mkIf (myMounts != {}) consumerFileSystems;
  };
}
