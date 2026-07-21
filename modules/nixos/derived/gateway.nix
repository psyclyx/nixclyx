# Egregore → gateway projection.
#
# Reads `host.gateway` + the network-graph data from egregore and
# emits the full `psyclyx.nixos.network.gateway.*` config. Gateway is
# enabled when the host's egregore entity sets host.gateway.lanInterface.
{config, lib, ...}: let
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;
  myHost = lib.attrByPath ["entities" hostname "host"] null eg;
  gw = if myHost == null then {} else (myHost.gateway or {});
  enabled = (gw.lanInterface or null) != null;

  # Networks this host is the gateway for. VLAN-backed only; overlay
  # networks (vpn) excluded.
  gatewayedNetworks = lib.filterAttrs
    (_: e:
      e.type == "network"
      && e.network.vlan != null
      && (e.attrs.gatewayRef or null) == hostname)
    eg.entities;
  gatewayedVlans = lib.sort builtins.lessThan
    (lib.mapAttrsToList (_: e: e.network.vlan) gatewayedNetworks);

  # Connected networks (host declares an interface).
  myConnectedNetworks =
    if myHost == null then []
    else lib.attrNames (myHost.interfaces or {});

  # Switch-routed networks → static routes via switch uplink address.
  # Computes IPv4 + IPv6 entries; networkd's [Route] is family-agnostic
  # so both go into the same per-VLAN list and end up on the same
  # network unit (the one carrying the uplink).
  switches = lib.filterAttrs (_: e: e.type == "routeros") eg.entities;
  ulaPrefix = eg.ipv6UlaPrefix or "";
  staticRoutesByVlan = let
    perSwitch = lib.mapAttrsToList (_swName: sw: let
      r = sw.routeros;
      uplinkName =
        if r.uplinkNetwork != null then r.uplinkNetwork
        else r.mgmtNetwork;
      uplinkNet = eg.entities.${uplinkName};
      nextHopV4 = r.addresses.${uplinkName}.ipv4 or null;
      nextHopV6 = r.addresses.${uplinkName}.ipv6 or null;
      mkRoute = netName: family: dest: gw: {
        inherit netName family;
        uplinkVlan = uplinkNet.network.vlan;
        destSubnet = dest;
        gateway = gw;
      };
      routedFor = netName: let
        netEnt = eg.entities.${netName};
        v4dest = "${netEnt.attrs.network4}/${toString netEnt.attrs.prefixLen}";
        ulaHex = netEnt.network.ulaSubnetHex or "";
        v6dest =
          if ulaPrefix != "" && ulaHex != ""
          then "${ulaPrefix}:${ulaHex}::/64"
          else null;
      in
        lib.optional (nextHopV4 != null) (mkRoute netName "ipv4" v4dest nextHopV4)
        ++ lib.optional (nextHopV6 != null && v6dest != null)
            (mkRoute netName "ipv6" v6dest nextHopV6);
    in lib.concatMap routedFor sw.attrs.routedNetworks)
      switches;
    flat = builtins.filter
      (r: r.gateway != null && !(builtins.elem r.netName myConnectedNetworks))
      (lib.flatten perSwitch);
  in lib.foldl' (acc: r:
    let vid = toString r.uplinkVlan; in
    acc // {
      ${vid} = (acc.${vid} or []) ++ [{ destination = r.destSubnet; gateway = r.gateway; }];
    }
  ) {} flat;

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
  in {
    id = vlanId;
    address4 = "${na.gateway4}/${toString na.prefixLen}";
    address6 = "${na.gateway6}/64";
    ulaPrefix = "${eg.ipv6UlaPrefix}:${net.network.ulaSubnetHex}::/64";
    pdSubnetId = net.network.ipv6PdSubnetId;
    inherit raDomains;
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
    if myHost == null then null
    else myHost.mac.${ifaceDev} or null;
  cakeQos = gw.cakeQos or null;
  cakeRates =
    if cakeQos == null
    then { download = { min = 0; base = 0; max = 0; }; upload = { min = 0; base = 0; max = 0; }; }
    else cakeQos;
  transitVlan = eg.conventions.transitVlan;
in {
  config = lib.mkIf enabled (lib.mkMerge [
    {
      psyclyx.nixos.network.gateway = {
        enable = true;
        lanInterface = gw.lanInterface;
        wanInterface = gw.wanInterface;
        lanAddress = gw.lanAddress;
        lanMac = macFor gw.lanInterface;
        wanMac = macFor gw.wanInterface;
        networks = projectedNetworks;
        transitVlan = lib.mkDefault transitVlan;
        transitDhcpV6 = {
          duidRawData = gw.transitDhcpV6.duidRawData or null;
          iaid = gw.transitDhcpV6.iaid or 250;
          prefixDelegationHint = gw.transitDhcpV6.prefixDelegationHint or "::/60";
        };
        transitDhcpV4.useRoutes = gw.transitDhcpV4.useRoutes or true;
        initrd = {
          enable = lib.mkDefault ((gw.initrdVlans or []) != []);
          kernelModules = gw.initrdKernelModules or [ "8021q" ];
          networks = projectedInitrdNetworks;
        };
      };
    }
    (lib.mkIf (cakeQos != null) {
      psyclyx.nixos.network.cake-qos = {
        enable = true;
        interface = "${gw.wanInterface}.${toString transitVlan}";
        inherit (cakeRates) download upload;
      };
    })
  ]);
}
