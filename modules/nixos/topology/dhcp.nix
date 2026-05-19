{config, lib, ...}: let
  eg = config.psyclyx.egregore;

  cfg = config.psyclyx.nixos.services.dhcp;

  hosts = lib.filterAttrs (_: e: e.type == "host") eg.entities;

  # Hosts with MAC addresses that have an interface on a given network.
  # PXE-mode hosts whose boot.pxeInterfaces contains this network are
  # skipped: the PXE projection emits their reservation separately, with
  # boot-file-name and next-server. Emitting both here would duplicate
  # the reservation by MAC, which Kea rejects.
  managedHostsOnNetwork = network:
    lib.sort builtins.lessThan
      (builtins.attrNames (lib.filterAttrs (_: e:
        e.host.mac != {}
        && e.host.interfaces ? ${network}
        && !((e.host.boot.mode or "local") == "pxe"
             && builtins.elem network (e.host.boot.pxeInterfaces or []))
      ) hosts));

  # MAC address for a host's physical interface on a network.
  # For bond VLAN devices (e.g. bond0.25), use the bond's MAC (eno1).
  hostMacForNetwork = hostname: network: let
    h = eg.entities.${hostname}.host;
    physDev = h.interfaces.${network}.device;
  in
    if h.mac ? ${physDev} then h.mac.${physDev}
    else h.mac.eno1;  # bond VLANs inherit the bond MAC

  # Classless static routes (DHCP option 121, RFC 3442) for networks
  # routed by something other than the pool's gateway. If a switch in
  # this site L3-routes some other network, clients on this pool should
  # send traffic for that network directly to the switch's IP on this
  # network — not via the pool's primary gateway, which would cause
  # asymmetric routing and break stateful forwarding at the gateway.
  #
  # RFC 3442 requires option-121-aware clients to IGNORE option 3
  # (default router) when option 121 is present. So whenever we emit
  # option 121 we must also include a default 0.0.0.0/0 entry, or
  # clients drop their default route entirely.
  #
  # Format: "<dst-prefix>-<via>, <dst-prefix>-<via>, ..." per Kea's
  # built-in option 121 type.
  classlessRoutesFor = pool: let
    sitePool = pool.network;
    poolNet = eg.entities.${sitePool}.attrs;

    switches = lib.filterAttrs (_: e: e.type == "routeros") eg.entities;

    # All routed networks across all switches in this site, paired with
    # the switch's IP on the POOL'S network (i.e. the next hop visible
    # to a client on this pool).
    switchRoutes = lib.flatten (lib.mapAttrsToList (_: sw: let
      r = sw.routeros;
      nextHopOnPoolNet = r.addresses.${sitePool}.ipv4 or null;
      routedHere = lib.filter (n: n != sitePool) sw.attrs.routedNetworks;
    in
      if nextHopOnPoolNet == null then []
      else map (netName: let
        destNet = eg.entities.${netName};
      in {
        dst = "${destNet.attrs.network4}/${toString destNet.attrs.prefixLen}";
        via = nextHopOnPoolNet;
      }) routedHere
    ) switches);

    # If we emit any classless routes, we must also re-state the
    # default route — RFC 3442 clients otherwise lose it.
    defaultRoute = lib.optional (switchRoutes != []) {
      dst = "0.0.0.0/0";
      via = poolNet.gateway4;
    };
    routes = switchRoutes ++ defaultRoute;
  in
    lib.concatMapStringsSep ", " (r: "${r.dst}-${r.via}") routes;

  # DNS server pushed to clients on a network: resolves the network's
  # `refs.dns` host (if set) to that host's address on this same
  # network. Falls back to the gateway IP (which is right when the
  # gateway also runs the resolver, but wrong for switch-routed
  # networks like lab/storage where mdf-agg01 isn't a resolver).
  dnsServerForNetwork = netName: net: let
    dnsHostName = net.refs.dns or null;
    dnsHost = if dnsHostName != null then eg.entities.${dnsHostName} else null;
    dnsHostAddr = if dnsHost != null
      then dnsHost.host.addresses.${netName} or null
      else null;
  in
    if dnsHostAddr != null && dnsHostAddr.ipv4 != null
    then dnsHostAddr.ipv4
    else net.attrs.gateway4;

  mkSubnet4 = _poolName: pool: let
    net = eg.entities.${pool.network};
    na = net.attrs;
    siteEntity = eg.entities.${net.network.site};
    siteDomain = siteEntity.site.domain;
    classless = classlessRoutesFor pool;
  in {
    id = na.vlan;
    subnet = "${na.prefix}.0/${toString na.prefixLen}";
    pools = [{pool = "${pool.ipv4Range.start} - ${pool.ipv4Range.end}";}];
    "option-data" = [
      { name = "routers"; data = na.gateway4; }
      { name = "domain-name-servers"; data = dnsServerForNetwork pool.network net; }
      { name = "domain-name"; data = siteDomain; }
      { name = "domain-search"; data = "${siteDomain}, ${na.zoneName}"; }
    ]
    ++ lib.optional (classless != "") {
      name = "classless-static-route";
      data = classless;
    };
    # Per-VLAN qualifying-suffix: each interface registers under its
    # own zone (e.g. lab-1.main.apt.psyclyx.net) instead of the site
    # apex. The site apex is static-only (siteZone seeds A records
    # from egregore data), avoiding the multi-interface last-write
    # collision that previously broke A/AAAA at the apex.
    ddns-qualifying-suffix = "${na.zoneName}.";
    reservations = let
      servers = managedHostsOnNetwork pool.network;
      labReservations = map (name: {
        "hw-address" = hostMacForNetwork name pool.network;
        "ip-address" = eg.entities.${name}.host.addresses.${pool.network}.ipv4;
        hostname = name;
      }) servers;
    in
      labReservations ++ pool.extraReservations;
  };

  mkSubnet6 = _poolName: pool: let
    net = eg.entities.${pool.network};
    na = net.attrs;
    prefix6 = "${eg.ipv6UlaPrefix}:${net.network.ulaSubnetHex}";
    siteEntity = eg.entities.${net.network.site};
    siteDomain = siteEntity.site.domain;
  in {
    id = na.vlan;
    subnet = na.subnet6;
    interface = "${cfg.interface}.${toString na.vlan}";
    pools = [{pool = "${prefix6}::${pool.ipv6Suffix.start} - ${prefix6}::${pool.ipv6Suffix.end}";}];
    "option-data" = [
      { name = "dns-servers"; data = na.gateway6; }
      { name = "domain-search"; data = "${siteDomain}, ${na.zoneName}"; }
    ];
    ddns-qualifying-suffix = "${na.zoneName}.";
    reservations = let
      servers = managedHostsOnNetwork pool.network;
    in map (name: {
      "hw-address" = hostMacForNetwork name pool.network;
      "ip-addresses" = [eg.entities.${name}.host.addresses.${pool.network}.ipv6];
      hostname = name;
    }) servers;
  };

  ipv6Pools = lib.filterAttrs (_: pool: pool.ipv6) cfg.pools;

  poolVlans = lib.sort builtins.lessThan
    (lib.mapAttrsToList (_: pool: eg.entities.${pool.network}.network.vlan) cfg.pools);

  interfaces = map (id: "${cfg.interface}.${toString id}") poolVlans;
in {
  options.psyclyx.nixos.services.dhcp = {
    enable = lib.mkEnableOption "DHCP server derived from egregore entities";

    pools = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          network = lib.mkOption { type = lib.types.str; };
          ipv4Range = lib.mkOption {
            type = lib.types.submodule {
              options = {
                start = lib.mkOption { type = lib.types.str; };
                end = lib.mkOption { type = lib.types.str; };
              };
            };
          };
          ipv6 = lib.mkOption { type = lib.types.bool; default = true; };
          ipv6Suffix = lib.mkOption {
            type = lib.types.submodule {
              options = {
                start = lib.mkOption { type = lib.types.str; default = "100"; };
                end = lib.mkOption { type = lib.types.str; default = "1ff"; };
              };
            };
            default = {};
          };
          extraReservations = lib.mkOption {
            type = lib.types.listOf lib.types.attrs;
            default = [];
          };
        };
      });
      default = {};
    };

    interface = lib.mkOption {
      type = lib.types.str;
      default = "bond0";
    };

    extraDhcp4 = lib.mkOption { type = lib.types.attrs; default = {}; };
    extraDhcp6 = lib.mkOption { type = lib.types.attrs; default = {}; };
  };

  config = lib.mkIf (cfg.enable && cfg.pools != {}) {
    services.kea.dhcp4 = {
      enable = true;
      settings = {
        interfaces-config.interfaces = interfaces;
        lease-database = { type = "memfile"; persist = true; name = "/var/lib/kea/dhcp4.leases"; };
        valid-lifetime = 43200;
        renew-timer = 10800;
        rebind-timer = 21600;
        subnet4 = lib.mapAttrsToList mkSubnet4 cfg.pools;
      } // cfg.extraDhcp4;
    };

    services.kea.dhcp6 = lib.mkIf (ipv6Pools != {}) {
      enable = true;
      settings = {
        interfaces-config.interfaces = interfaces;
        lease-database = { type = "memfile"; persist = true; name = "/var/lib/kea/dhcp6.leases"; };
        valid-lifetime = 43200;
        renew-timer = 10800;
        rebind-timer = 21600;
        subnet6 = lib.mapAttrsToList mkSubnet6 ipv6Pools;
        host-reservation-identifiers = ["hw-address" "duid"];
        mac-sources = ["ipv6-link-local"];
      } // cfg.extraDhcp6;
    };
  };
}
