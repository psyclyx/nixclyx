{config, lib, ...}: let
  eg = config.psyclyx.egregore;

  cfg = config.psyclyx.nixos.services.dhcp;

  hostname = config.psyclyx.nixos.host or null;
  me = if hostname == null then null else eg.entities.${hostname}.host or null;

  hosts = lib.filterAttrs (_: e: e.host != null) eg.entities;

  # Hosts with MAC addresses that have an interface on a given network.
  #
  # This used to skip PXE-mode hosts on their boot.pxeInterfaces, because
  # the PXE projection emitted those reservations itself (carrying
  # next-server and boot-file-name) and two reservations for one MAC is
  # something Kea rejects. That projection is gone, so the exception goes
  # with it: a PXE-mode host is just a host, and gets the ordinary
  # reservation that keeps it addressable.
  managedHostsOnNetwork = network:
    lib.sort builtins.lessThan
      (builtins.attrNames (lib.filterAttrs (_: e:
        e.host.mac != {}
        && e.host.interfaces ? ${network}
        && e.host.addresses ? ${network}
      ) hosts));

  # MAC address for a host's interface on a network. VLAN sub-ifaces
  # (e.g. enp1s0.10 or bond0.25) inherit the parent's MAC, so we strip
  # the dotted VLAN suffix and look up the base device.
  hostMacForNetwork = hostname: network: let
    h = eg.entities.${hostname}.host;
    physDev = h.interfaces.${network}.device;
    parentDev = let
      parts = lib.splitString "." physDev;
    in
      if builtins.length parts > 1
      then builtins.head parts
      else physDev;
  in
    if h.mac ? ${physDev} then h.mac.${physDev}
    else if h.mac ? ${parentDev} then h.mac.${parentDev}
    else h.mac.eno1 or null;  # last-resort lab-bond fallback

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
    poolNet = eg.entities.${sitePool};

    switches = lib.filterAttrs (_: e: e.routeros != null) eg.entities;

    # All routed networks across all switches in this site, paired with
    # the switch's IP on the POOL'S network (i.e. the next hop visible
    # to a client on this pool).
    switchRoutes = lib.flatten (lib.mapAttrsToList (_: sw: let
      r = sw.routeros;
      nextHopOnPoolNet = r.addresses.${sitePool}.ipv4 or null;
      routedHere = lib.filter
        (n: n != sitePool && (eg.entities.${n}.network or null) != null)
        (sw.refsIn.gateway or []);
    in
      if nextHopOnPoolNet == null then []
      else map (netName: let
        destNet = eg.entities.${netName};
      in {
        dst = "${destNet.network4}/${toString destNet.prefixLen}";
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

  # DNS server pushed to clients on a network, per family: the address of
  # the network's resolver (`dnsRef`, honouring the site-level ref).
  #
  # There is deliberately no fall back to the gateway address. That was
  # only ever right while the resolver and the gateway were the same box,
  # and moving routing onto the switch is exactly the change that makes
  # them different — the fallback would have quietly handed every client
  # a switch as its nameserver. A resolver we can't find an address for
  # is a configuration error, and saying so at eval time is better than
  # shipping a lie in a DHCP option.
  dnsServerForNetwork = family: netName: net: let
    na = net;
    resolverHost = na.dnsRef or null;
    resolver =
      if resolverHost == null then null
      else eg.entities.${resolverHost} or null;
    onLink =
      if resolver == null then null
      else ((resolver.addresses or {}).${netName} or {}).${family} or null;
    # A router holds its segment's gateway address by convention rather
    # than by declaring it, so "the resolver is this family's gateway"
    # is the one case where the gateway address is the right answer.
    # Per family: the two can differ, and on main they do.
    gatewayRefFor =
      if family == "ipv4" then na.gatewayRef or null else na.gateway6Ref or null;
  in
    if onLink != null then onLink
    else if resolverHost != null && resolverHost == gatewayRefFor
    then (if family == "ipv4" then na.gateway4 else na.gateway6)
    else throw ("network '${netName}': resolver '${toString resolverHost}' has no "
      + "${family} address there, and isn't its ${family} gateway — nothing "
      + "valid to advertise as a nameserver");

  mkSubnet4 = _poolName: pool: let
    net = eg.entities.${pool.network};
    na = net;
    siteEntity = eg.entities.${net.network.site};
    siteDomain = siteEntity.site.domain;
    classless = classlessRoutesFor pool;
  in {
    id = na.vlan;
    subnet = "${na.prefix}.0/${toString na.prefixLen}";
    pools = [{pool = "${pool.ipv4Range.start} - ${pool.ipv4Range.end}";}];
    "option-data" = [
      { name = "routers"; data = na.gateway4; }
      { name = "domain-name-servers"; data = dnsServerForNetwork "ipv4" pool.network net; }
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
    na = net;
    prefix6 = "${eg.ipv6UlaPrefix}:${net.network.ulaSubnetHex}";
    siteEntity = eg.entities.${net.network.site};
    siteDomain = siteEntity.site.domain;
  in {
    id = na.vlan;
    subnet = na.subnet6;
    interface = poolInterface pool;
    pools = [{pool = "${prefix6}::${pool.ipv6Suffix.start} - ${prefix6}::${pool.ipv6Suffix.end}";}];
    "option-data" = [
      { name = "dns-servers"; data = dnsServerForNetwork "ipv6" pool.network net; }
      { name = "domain-search"; data = "${siteDomain}, ${na.zoneName}"; }
    ];
    ddns-qualifying-suffix = "${na.zoneName}.";
    reservations = let
      # Only hosts that actually have a v6 address on this network get a
      # v6 reservation; a v4-only L2 anchor (e.g. iyr on a routed lab/
      # storage VLAN) would otherwise emit `"ip-addresses": [null]`,
      # which kea >=3.0.3 rejects as a syntax error.
      servers = lib.filter
        (name: (eg.entities.${name}.host.addresses.${pool.network}.ipv6 or null) != null)
        (managedHostsOnNetwork pool.network);
    in map (name: {
      "hw-address" = hostMacForNetwork name pool.network;
      "ip-addresses" = [eg.entities.${name}.host.addresses.${pool.network}.ipv6];
      hostname = name;
    }) servers;
  };

  ipv6Pools = lib.filterAttrs (_: pool: pool.ipv6) cfg.pools;

  # A subnet per delegation, holding the pool the binder maintains. The
  # prefix is a placeholder: it is replaced at runtime with a slice of
  # whatever the upstream delegation currently is, and writing a real
  # one here would be the hardcoding this whole mechanism exists to
  # avoid. `::/64` is unroutable and obviously not an answer, which is
  # the point — if the binder never runs, nothing is delegated.
  delegationSubnets = lib.mapAttrsToList (name: d: let
    net = eg.entities.${d.network};
  in {
    id = 900 + net.network.vlan;
    subnet = net.subnet6;
    interface = me.interfaces.${d.network}.device;
    pd-pools = [{
      prefix = "::";
      prefix-len = d.prefixLength;
      delegated-len = d.prefixLength;
      user-context = { psyclyx-delegation = name; };
    }];
  }) cfg.delegations;

  # Interfaces Kea listens on: wherever a pool's traffic actually
  # arrives. For a segment this host sits on, that's its own interface
  # there. For a segment reached only through a relay, it's the link the
  # relay sends over — the relayed request carries giaddr, so the server
  # picks the subnet from that rather than from the arrival interface.
  #
  # Derived from declared interfaces rather than assuming one VLAN
  # sub-interface per pool. That assumption holds only while the server
  # is L2-present on every segment it serves, which is the arrangement
  # relaying exists to end.
  poolInterface = pool:
    if me != null && me.interfaces ? ${pool.network}
    then me.interfaces.${pool.network}.device
    else cfg.relayInterface;

  interfaces = lib.sort builtins.lessThan (lib.unique
    (lib.mapAttrsToList (_: poolInterface) cfg.pools));
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
      description = "Trunk parent carrying this host's VLAN sub-interfaces.";
    };

    delegations = lib.mkOption {
      default = {};
      description = ''
        Prefix delegations this server hands downstream, keyed by the
        receiving router. Declares the pool; the prefix inside it is
        maintained at runtime by the prefix-delegation binder, because
        the upstream delegation is dynamic and Kea's pools are not.

        The pool carries a `user-context` marker naming the receiver,
        which is how the binder finds the one it owns without depending
        on subnet ids or ordering.
      '';
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          network = lib.mkOption {
            type = lib.types.str;
            description = "Network the receiving router is reached over.";
          };
          prefixLength = lib.mkOption {
            type = lib.types.int;
            description = "Size of the delegated slice.";
          };
        };
      });
    };

    controlSocket = lib.mkOption {
      type = lib.types.path;
      default = "/run/kea/kea-dhcp6-ctrl.sock";
      description = "Kea DHCPv6 control socket, for runtime pool updates.";
    };

    relayInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Link that relayed requests arrive over, for pools on segments
        this host has no interface on. A relayed request carries giaddr,
        so the subnet is chosen from that rather than from the arrival
        interface — the server only has to be listening somewhere the
        relay can reach it.
      '';
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

    services.kea.dhcp6 = lib.mkIf (ipv6Pools != {} || cfg.delegations != {}) {
      enable = true;
      settings = {
        interfaces-config.interfaces = interfaces;
        lease-database = { type = "memfile"; persist = true; name = "/var/lib/kea/dhcp6.leases"; };
        valid-lifetime = 43200;
        renew-timer = 10800;
        rebind-timer = 21600;
        subnet6 = lib.mapAttrsToList mkSubnet6 ipv6Pools ++ delegationSubnets;
        # The binder replaces the delegation pool's prefix at runtime;
        # config-set needs somewhere to say so.
        control-socket = {
          socket-type = "unix";
          socket-name = cfg.controlSocket;
        };
        host-reservation-identifiers = ["hw-address" "duid"];
        mac-sources = ["ipv6-link-local"];
      } // cfg.extraDhcp6;
    };
  };
}
