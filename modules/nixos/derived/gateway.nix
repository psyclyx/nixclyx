# Egregore → gateway projection.
#
# The gateway's mechanism (interfaces, DHCP clients, QoS) is host config
# (psyclyx.nixos.network.gateway.*); this projection supplies what is
# derived from the fleet: the set of routed segments, the LAN/WAN MACs
# looked up from host.mac, the transit VLAN, and the initrd VLANs.
{config, lib, ...}: let
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;
  myHost = lib.attrByPath ["entities" hostname "host"] null eg;
  gw = if myHost == null then {} else (myHost.gateway or {});
  mech = config.psyclyx.nixos.network.gateway;
  enabled = mech.enable;

  # Networks this host routes, by family, read from the resolved inverse
  # of the network graph: a network whose gateway (or gateway6) resolves
  # to this host lists it in refsIn, whether it said so literally or
  # inherited it from its site. VLAN-backed only; overlays excluded.
  #
  # The two families are asked separately because they can differ. A
  # host that routes only v6 for a segment still holds the ULA address
  # and sends the RAs there; it just doesn't hold the v4 gateway
  # address. Asking one question for both would mean handing over v4
  # also silently hands over router advertisements, the advertised
  # resolver, and the prefix delegation.
  myRefsIn = lib.attrByPath ["entities" hostname "refsIn"] {} eg;
  v4Gatewayed = myRefsIn.gateway or [];
  v6Gatewayed = myRefsIn.gateway6 or [];
  isV4Gateway = e: builtins.elem e.attrs.name v4Gatewayed;
  isV6Gateway = e: builtins.elem e.attrs.name v6Gatewayed;
  gatewayedNetworks = lib.filterAttrs
    (_: e:
      e.type == "network"
      && e.network.vlan != null
      && (isV4Gateway e || isV6Gateway e))
    eg.entities;
  gatewayedVlans = lib.sort builtins.lessThan
    (lib.mapAttrsToList (_: e: e.network.vlan) gatewayedNetworks);

  # Connected networks (host declares an interface).
  myConnectedNetworks =
    if myHost == null then []
    else lib.attrNames (myHost.interfaces or {});

  # Static routes this host installs, read from route entities rather
  # than reconstructed from someone else's topology. A route names what
  # every routing table names: a destination, a next hop, and the link
  # to reach it over — so it lands on the network unit for `refs.over`.
  staticRoutesByVlan = let
    myRoutes = map (n: eg.entities.${n})
      (eg.entities.${hostname}.refsIn.on or []);
    onLink = r: eg.entities.${r.refs.over}.network.vlan;
  in lib.foldl' (acc: r:
    let vid = toString (onLink r); in
    acc // {
      ${vid} = (acc.${vid} or []) ++ [{
        destination = r.attrs.dst;
        inherit (r.attrs) gateway;
      }];
    }
  ) {} (builtins.filter (r: r.attrs.gateway != null) myRoutes);

  mkGatewayNet = vlanId: let
    name = lib.head (lib.attrNames (lib.filterAttrs
      (_: e: e.network.vlan == vlanId) gatewayedNetworks));
    net = eg.entities.${name};
    na = net.attrs;
    siteEntity =
      if net.network.site != null
      then eg.entities.${net.network.site} or null
      else null;
    siteDomain = if siteEntity != null then siteEntity.site.domain else null;
    internalDomain = eg.domains.internal or null;
    raDomains =
      lib.optional (internalDomain != null && internalDomain != "") "~${internalDomain}"
      ++ lib.optional (siteDomain != null) siteDomain
      ++ [ na.zoneName ];

    # Resolver advertised in RA (RDNSS): the network's dnsRef host's own
    # IPv6 on this network — or the gateway IPv6 when the resolver *is* the
    # gateway — falling back to the gateway IPv6. Pinning to the resolver
    # host (not blindly the gateway) keeps DNS correct when inter-VLAN
    # routing is offloaded off the gateway onto a switch. Mirrors the same
    # resolution in derived/dhcp.nix so RA RDNSS and DHCPv6 dns-servers agree.
    resolverHost = na.dnsRef or null;
    resolver6FromHost =
      if resolverHost == null || resolverHost == (na.gatewayRef or null)
      then null
      else (eg.entities.${resolverHost}.host.addresses.${name} or {}).ipv6 or null;
    resolver6 = if resolver6FromHost != null then resolver6FromHost else na.gateway6;
    v4 = isV4Gateway net;
    v6 = isV6Gateway net;
    declared = if myHost == null then {} else myHost.addresses.${name} or {};
    declared4 = declared.ipv4 or null;
    declared6 = declared.ipv6 or null;
  in {
    id = vlanId;
    # This host's address on the segment: the gateway address when it
    # routes that family, its own declared address when it doesn't but
    # is still present here. A router that hands v4 over to someone else
    # usually keeps an address on the segment — it still resolves, still
    # serves DHCP, still has to be reachable — and that address is a
    # declared fact rather than the gateway convention.
    address4 =
      if v4 then "${na.gateway4}/${toString na.prefixLen}"
      else if declared4 != null then "${declared4}/${toString na.prefixLen}"
      else null;
    address6 =
      if v6 then "${na.gateway6}/64"
      else if declared6 != null then "${declared6}/64"
      else null;
    ulaPrefix =
      if v6 then "${eg.ipv6UlaPrefix}:${net.network.ulaSubnetHex}::/64" else null;
    pdSubnetId = if v6 then net.network.ipv6PdSubnetId else null;
    raDomains = if v6 then raDomains else [];
    dnsServers =
      lib.optional (v6 && resolver6 != null && resolver6 != "") resolver6;
    # Transit links are point-to-point router↔router; no RA (no SLAAC
    # clients, and two routers advertising to each other is just noise).
    sendRA = v6 && !(builtins.elem "transit" (net.tags or []));
    staticRoutes = staticRoutesByVlan.${toString vlanId} or [];
  };

  projectedNetworks = map mkGatewayNet gatewayedVlans;

  # Initrd VLANs: resolve egregore network names to vlan id + the
  # host's gateway address on that network.
  projectedInitrdNetworks = map (name: let
    net = eg.entities.${name};
    na = net.attrs;
  in {
    id = net.network.vlan;
    address4 = "${na.gateway4}/${toString na.prefixLen}";
  }) gw.initrdVlans or [];

  # MACs from host.mac, looked up by interface device name.
  macFor = ifaceDev:
    if myHost == null || ifaceDev == null then null
    else myHost.mac.${ifaceDev} or null;
  transitVlan = eg.conventions.transitVlan;
in {
  config = lib.mkIf enabled {
    psyclyx.nixos.network.gateway = {
      lanMac = macFor mech.lanInterface;
      wanMac = macFor mech.wanInterface;
      networks = projectedNetworks;
      transitVlan = lib.mkDefault transitVlan;
      initrd = {
        enable = lib.mkDefault ((gw.initrdVlans or []) != [ ]);
        networks = projectedInitrdNetworks;
      };
    };
  };
}
