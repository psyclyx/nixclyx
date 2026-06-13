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
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;
  me = eg.entities.${hostname} or null;

  allExports = lib.filterAttrs (_: e: e.type == "nfs-export") eg.entities;

  # Producer-side: exports we host.
  myExports = lib.filterAttrs (_: e:
    (e.refs.producer or null) == hostname
  ) allExports;

  # Look up a consumer host's source IP for the export ACL. Defaults
  # to the export's `network`; overridden via `consumerNetwork` when
  # the consumer's L3-routed source lives on a different VLAN than the
  # one the server binds on.
  consumerAclNetwork = e:
    if (e.nfs-export.consumerNetwork or null) != null
    then e.nfs-export.consumerNetwork
    else e.nfs-export.network;
  consumerIp = consumer: network:
    eg.entities.${consumer}.host.addresses.${network}.ipv4;

  # Default per-client options. Append sec= when the export demands
  # Kerberos so each client line carries it (exports(5) supports
  # per-client sec).
  baseClientOpts = [ "sync" "no_subtree_check" "no_root_squash" ];

  mkServerExport = _expName: e: {
    path = e.nfs-export.path;
    clients = map (c: {
      address = consumerIp c (consumerAclNetwork e);
      readOnly = e.nfs-export.readOnly;
      options = baseClientOpts
        ++ lib.optional (e.nfs-export.sec != "sys") "sec=${e.nfs-export.sec}";
    }) e.nfs-export.consumers;
  };

  serverExports = lib.mapAttrsToList mkServerExport myExports;

  # Does this host participate in any Kerberos-secured NFS, either as
  # producer or consumer? Drives gssproxy enablement.
  needsKrb = builtins.any (e:
    (e.nfs-export.sec or "sys") != "sys"
    && ((e.refs.producer or null) == hostname
        || builtins.elem hostname e.nfs-export.consumers)
  ) (lib.attrValues allExports);

  # Consumer-side: exports we mount.
  #
  # Excludes exports produced by this consumer's hypervisor — that's a
  # co-located VM/host pair, and a VM cannot reach its hypervisor
  # through macvtap. For those, topology/vms.nix attaches the export
  # path directly as a virtiofs share, no NFS hop.
  myHypervisor = (me.refs or {}).hypervisor or null;
  myMounts = lib.filterAttrs (_: e:
    e.nfs-export.mountAt != null
    && builtins.elem hostname e.nfs-export.consumers
    && (myHypervisor == null || (e.refs.producer or null) != myHypervisor)
  ) allExports;

  # Producer's address on the export's network. krb5 mounts use the
  # FQDN so the client requests the matching `nfs/<fqdn>` service
  # ticket; sec=sys mounts use the IP to avoid a DNS dependency at
  # mount time.
  producerEndpoint = e: let
    producer = eg.entities.${e.refs.producer};
    net = e.nfs-export.network;
  in
    if e.nfs-export.sec != "sys"
    then producer.attrs.fqdns.${net} or producer.host.addresses.${net}.ipv4
    else producer.host.addresses.${net}.ipv4;

  mkConsumerMount = _expName: e: {
    name = e.nfs-export.mountAt;
    value = {
      device = "${producerEndpoint e}:${e.nfs-export.path}";
      fsType = "nfs";
      options = [ "_netdev" "nofail" "x-systemd.device-timeout=30s" ]
        ++ lib.optional (e.nfs-export.sec != "sys") "sec=${e.nfs-export.sec}"
        ++ e.nfs-export.options;
    };
  };

  consumerFileSystems = lib.mapAttrs' mkConsumerMount myMounts;

  # krb5 mounts use the producer FQDN as the device (so rpc.gssd
  # requests the matching nfs/<fqdn> service ticket). The site zones
  # publish both an A and an AAAA for that FQDN, and an off-rack
  # consumer that prefers IPv6 would route over the inter-VLAN v6 path
  # — which black-holes at the app layer — and the mount stalls. The
  # export ACL keys on the consumer's routable IPv4 source anyway, so
  # IPv4 is the only authorized path. Pin the FQDN to the producer's
  # IPv4 on the export network via /etc/hosts (files before dns) so
  # the kernel always picks v4 while gssd still sees the right name.
  krbMountHostPins = lib.listToAttrs (lib.concatLists (lib.mapAttrsToList
    (_: e:
      let
        producer = eg.entities.${e.refs.producer};
        net = e.nfs-export.network;
        fqdn = producer.attrs.fqdns.${net} or null;
        ipv4 = producer.host.addresses.${net}.ipv4 or null;
      in
      lib.optional (e.nfs-export.sec != "sys" && fqdn != null && ipv4 != null)
        (lib.nameValuePair ipv4 [ fqdn ]))
    myMounts));
in {
  config = lib.mkIf (me != null) (lib.mkMerge [
    {
      psyclyx.nixos.services.nfs-server = lib.mkIf (myExports != {}) {
        enable = true;
        exports = serverExports;
      };

      fileSystems = lib.mkIf (myMounts != {}) consumerFileSystems;

      # Force krb5 NFS mounts onto the producer's export-network IPv4
      # (see krbMountHostPins above).
      networking.hosts = lib.mkIf (krbMountHostPins != {}) krbMountHostPins;
    }
    # Kerberos NFS: nixpkgs's nfs module auto-enables rpc-gssd /
    # rpc-svcgssd via systemd ConditionPathExists=/etc/krb5.keytab, so
    # we don't need to flip any services.* option here. rpcbind is
    # required even for NFSv4-only because nfs-mountd registers via
    # portmap on the server side.
    #
    # NFSv4 idmap domain MUST match on client + server, otherwise
    # principal@REALM → UID mapping falls back to Nobody-User and
    # permission denied ensues. Derived from globals.kerberos.realm
    # (lowercased dotted form).
    (lib.mkIf needsKrb {
      services.rpcbind.enable = true;
      services.nfs.idmapd.settings.General.Domain =
        lib.toLower (eg.kerberos.realm or "");
    })
  ]);
}
