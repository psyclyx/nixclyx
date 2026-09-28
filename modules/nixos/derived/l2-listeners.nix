# Egregore → L2-only network listeners on gateway hosts.
#
# A gateway host's "main" VLANs (the ones it routes) are emitted by
# derived/gateway.nix. But a gateway host may also have addresses on
# *other* VLANs that it doesn't route — e.g. switch-routed VLANs where
# it still needs L2 presence to serve DHCP or DNS. This projection
# declares the VLAN netdev + L3 address for each such network in the
# generic interfaces module; parent-unit VLAN aggregation in
# network/interfaces.nix then attaches them to the host's lanInterface
# automatically.
#
# Scoped to gateway hosts (`network.gateway.enable = true`). Non-
# gateway hosts use derived/network.nix, which handles their entire
# network interface set including non-gateway VLANs.
#
# Use case today: iyr (apt-site gateway) is an L2-only DHCP + DNS
# listener on the switch-routed `lab` and `storage` VLANs (mdf-agg01
# is their L3 gateway).
{config, lib, ...}: let
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;
  enabled = config.psyclyx.nixos.network.gateway.enable;

  me = lib.attrByPath ["entities" hostname "host"] null eg;

  # Networks whose resolved gateway is this host in *either* family, read
  # from the graph inverse so a network that inherited its gateway from
  # its site counts too.
  #
  # Both families have to count. The apartment's v4 gateways moved to
  # mdf-agg01 while iyr kept the v6 ones: iyr terminates the Xfinity
  # prefix delegation, so it is the only thing that can send RA for the
  # delegated GUA. That leaves networks with `gateway = mdf-agg01` and
  # `gateway6 = iyr` — and those interfaces belong to derived/gateway.nix,
  # which emits their RA, prefix delegation and routes.
  #
  # Claiming them here too puts a second .network file on the same link,
  # and systemd-networkd applies only the lexicographically-first match
  # per interface rather than merging. The listener file (20-) sorts ahead
  # of the gateway one (31-), so it would silently shadow it — dropping
  # the ULA ::1, IPv6SendRA, DHCPPrefixDelegation and the per-peer routes,
  # and taking the address this host is managed on down with them.
  gatewayed =
    lib.attrByPath ["entities" hostname "refsIn" "gateway"] [] eg
    ++ lib.attrByPath ["entities" hostname "refsIn" "gateway6"] [] eg;

  # Networks where:
  #  - host has a declared address (host.addresses.X exists)
  #  - host has a declared interface (host.interfaces.X exists)
  #  - host is NOT the gateway for the network in either family
  #  - the network is VLAN-backed (has a vlan id)
  listenerNetworks =
    if me == null then {}
    else lib.filterAttrs (netName: _addr:
      let
        netEnt = eg.entities.${netName} or null;
        vlan = if netEnt == null then null
               else netEnt.network.vlan or null;
      in
        netEnt != null
        && (me.interfaces or {}) ? ${netName}
        && !(builtins.elem netName gatewayed)
        && vlan != null
    ) (me.addresses or {});

  mkListener = netName: addr: let
    netEnt = eg.entities.${netName};
    na = netEnt;
    device = me.interfaces.${netName}.device;
    parentExpected = "${lib.removeSuffix ".${toString netEnt.network.vlan}" device}";
  in {
    vlans.${device} = {
      id = netEnt.network.vlan;
      parent = parentExpected;
    };
    networks.${device} = {
      addresses = [ "${addr.ipv4}/${toString na.prefixLen}" ]
        ++ lib.optional (addr.ipv6 or null != null) "${addr.ipv6}/64";
      requiredForOnline = "no";
      mtu = netEnt.network.mtu;
    };
  };
in {
  config = lib.mkIf (enabled && listenerNetworks != {}) {
    psyclyx.nixos.network.interfaces = lib.foldl' lib.recursiveUpdate {}
      (lib.mapAttrsToList mkListener listenerNetworks);
  };
}
