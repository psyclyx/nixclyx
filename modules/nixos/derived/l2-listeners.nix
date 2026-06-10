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

  # Networks where:
  #  - host has a declared address (host.addresses.X exists)
  #  - host has a declared interface (host.interfaces.X exists)
  #  - host is NOT the gateway for the network
  #  - the network is VLAN-backed (has a vlan id)
  listenerNetworks =
    if me == null then {}
    else lib.filterAttrs (netName: _addr:
      let
        netEnt = eg.entities.${netName} or null;
        gw = if netEnt == null then null else netEnt.attrs.gatewayRef or null;
        vlan = if netEnt == null then null
               else netEnt.network.vlan or null;
      in
        netEnt != null
        && (me.interfaces or {}) ? ${netName}
        && gw != hostname
        && vlan != null
    ) (me.addresses or {});

  mkListener = netName: addr: let
    netEnt = eg.entities.${netName};
    na = netEnt.attrs;
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
