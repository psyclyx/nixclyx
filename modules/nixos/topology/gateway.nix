# Egregore → gateway projection.
#
# Reads `config.psyclyx.egregore` for networks where the current host
# is the gateway and populates the generic `psyclyx.nixos.network.gateway.*`
# module's `networks`, static-route, and initrd-VLAN data. The generic
# module handles the actual networkd emission; the only thing fleet-aware
# here is the egregore lookup.
{config, lib, ...}: let
  cfg = config.psyclyx.nixos.network.gateway;
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;

  # Networks this host is the gateway for. VLAN-backed only; overlay
  # networks (vpn) excluded. Switch-routed networks live downstream and
  # are reached via static routes hung off our VLAN units.
  gatewayedNetworks = lib.filterAttrs
    (_: e:
      e.type == "network"
      && e.network.vlan != null
      && (e.attrs.gatewayRef or null) == hostname)
    eg.entities;
  gatewayedVlans = lib.sort builtins.lessThan
    (lib.mapAttrsToList (_: e: e.network.vlan) gatewayedNetworks);

  # Connected networks (host has a declared interface). Used to skip
  # static routes for subnets already on a directly-connected VLAN.
  myHost = eg.entities.${hostname}.host or null;
  myConnectedNetworks =
    if myHost == null then []
    else lib.attrNames (myHost.interfaces or {});

  # Switch-routed networks: per routeros entity, every routedNetwork
  # gets a static route via the switch's uplinkNetwork address.
  switches = lib.filterAttrs (_: e: e.type == "routeros") eg.entities;
  staticRoutesByVlan = let
    perSwitch = lib.mapAttrsToList (_swName: sw: let
      r = sw.routeros;
      uplinkName =
        if r.uplinkNetwork != null then r.uplinkNetwork
        else r.mgmtNetwork;
      uplinkNet = eg.entities.${uplinkName};
      nextHopV4 = r.addresses.${uplinkName}.ipv4 or null;
    in map (netName: {
      inherit netName;
      uplinkVlan = uplinkNet.network.vlan;
      destSubnet = "${eg.entities.${netName}.attrs.network4}/${toString eg.entities.${netName}.attrs.prefixLen}";
      gateway = nextHopV4;
    }) sw.attrs.routedNetworks)
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
  projectedInitrdNetworks = map (name: let
    net = eg.entities.${name};
    na = net.attrs;
  in {
    id = net.network.vlan;
    address4 = "${na.gateway4}/${toString na.prefixLen}";
  }) cfg.initrdVlans;
in {
  options.psyclyx.nixos.network.gateway = {
    transitVlanFromGlobals = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Derive transitVlan from egregore globals (`conventions.transitVlan`)
        rather than requiring the host to set it explicitly.
      '';
    };
    initrdVlans = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Egregore network names whose gateway addresses should come up
        in initrd. The projection resolves these to VLAN ids + the
        host's gateway address on each and passes them to
        `gateway.initrd.networks`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    psyclyx.nixos.network.gateway = {
      networks = projectedNetworks;
      transitVlan = lib.mkIf cfg.transitVlanFromGlobals
        (lib.mkDefault eg.conventions.transitVlan);
      initrd = {
        enable = lib.mkDefault (cfg.initrdVlans != []);
        networks = projectedInitrdNetworks;
      };
    };
  };
}
