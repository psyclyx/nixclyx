# Entity type: MikroTik RouterOS switch.
{
  egregoreType = { lib, egregorLib, ... }: let
    portDef = import ../lib/switch-port.nix { inherit lib egregorLib; };
    portType = portDef.portType;
    portLabel = portDef.portLabel;

    # Hardware port lists for known models.
    modelPorts = {
      "CRS326-24S+2Q+RM" =
        (map (i: "sfp-sfpplus${toString i}") (lib.range 1 24))
        ++ (lib.concatMap (q:
          map (s: "qsfpplus${toString q}-${toString s}") (lib.range 1 4)
        ) (lib.range 1 2));
      "CRS305-1G-4S+IN" =
        ["ether1"] ++ map (i: "sfp-sfpplus${toString i}") (lib.range 1 4);
    };
  in {
    name = "routeros";
    description = "MikroTik RouterOS managed switch.";

    options = {
      model = lib.mkOption { type = lib.types.str; default = ""; };
      identity = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      addresses = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            ipv4 = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
            ipv6 = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
          };
        });
        default = {};
        description = ''
          Addresses this switch holds, keyed by network entity name. The
          mgmt entry is required (it backs the SSH/SNMP/management plane).
          Additional entries are emitted as L3 interfaces — for networks
          Every entry becomes an /interface vlan + /ip address, and with
          l3-hw-offloading on, one the chip routes. Whether the switch is
          the network's *canonical* gateway is a separate question,
          answered by the network's own refs.gateway.
        '';
      };
      ports = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule portDef.module);
        default = {};
      };
      mgmtNetwork = lib.mkOption {
        type = lib.types.str;
        default = "mgmt";
        description = "Network entity name providing the management plane (SSH/SNMP).";
      };
      l3HwOffload = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable hardware-offloaded inter-VLAN routing on the switch chip.
          Supported on CRS3xx (Marvell Prestera) running RouterOS 7.6+.
        '';
      };
      primarySwitchChip = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Name of the switch chip that carries the L3 offload settings.
          A device may report several — one per switch ASIC — with the
          L3 settings belonging to the primary. Read the name off the
          device with `/interface ethernet switch print`.

          Null means there is no switch chip to configure, and is the
          default: a name that happens to be right for one vendor's
          model numbering is a fact about that model, not about the
          type, and guessing it here would put it at the wrong layer.
        '';
      };
      ipv6Forward = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = ''
          Software-level IPv6 forwarding. RouterOS defaults this to
          `no`, so even with l3-hw-offloading=yes + ipv6-hw=yes,
          IPv6 packets between VLANs go nowhere until this is on.
          Null leaves the device's current value; true emits
          `/ipv6 settings set forward=yes`.
        '';
      };
      l3HwSettings = lib.mkOption {
        type = lib.types.submodule {
          options = {
            ipv6Hw = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              default = null;
              description = ''
                Offload IPv6 routing to the switch chip. Off by default
                on CRS3xx even when l3HwOffload is on (the IPv6 path was
                added in RouterOS 7.6 and is a separate toggle). IPv4
                and IPv6 share the same hardware table; enabling adds
                no memory overhead until v6 routes appear.
              '';
            };
            icmpReplyOnError = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              default = null;
              description = ''
                Have the switch reply with ICMP errors (TTL exceeded,
                destination unreachable) for hardware-routed packets.
                Off means errors silently drop, which is fast but bad
                for traceroute and path-MTU discovery.
              '';
            };
          };
        };
        default = {};
        description = ''
          Per-chip L3 hardware offload knobs. Maps to
          `/interface ethernet switch l3hw-settings set ...`. The
          per-switch `l3HwOffload` flag is what gates the feature;
          these are additional sub-knobs.
        '';
      };
      timezone = lib.mkOption {
        type = lib.types.str;
        default = "America/Los_Angeles";
        description = "System timezone for the switch.";
      };
      sshUser = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "SSH user for admin key injection.";
      };
      bridge = lib.mkOption {
        type = lib.types.submodule {
          options.multicast = lib.mkOption {
            type = lib.types.submodule {
              options = {
                snooping = lib.mkOption { type = lib.types.bool; default = true; };
                querier = lib.mkOption { type = lib.types.bool; default = false; };
                router = lib.mkOption {
                  type = lib.types.enum [ "disabled" "temporary-query" "permanent" ];
                  default = "temporary-query";
                };
                igmpVersion = lib.mkOption { type = lib.types.enum [ 2 3 ]; default = 3; };
                mldVersion = lib.mkOption { type = lib.types.enum [ 1 2 ]; default = 2; };
              };
            };
            default = {};
          };
        };
        default = {};
      };
      bonds = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            mode = lib.mkOption { type = lib.types.str; default = ""; };
            slaves = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
            lacpMode = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
            comment = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
          };
        });
        default = {};
      };
    };

    attrs = name: entity: top: let
      r = entity.routeros;
      active = lib.filterAttrs (_: p: portType p != "unused") r.ports;
      mgmtAddr = r.addresses.${r.mgmtNetwork}.ipv4 or null;
    in {
      address = mgmtAddr;
      # Addresses keyed by network, the same shape a host exposes.
      # Anything asking "what address does this device have on network
      # N" — a route resolving its next hop, a relay resolving its
      # server — can then ask without first working out what kind of
      # device it is talking to.
      addresses = r.addresses;
      label = "${if r.identity != null then r.identity else name} (${r.model})";
      platform = "routeros";
      model = r.model;
      portCount = builtins.length (builtins.attrNames r.ports);
      activePortCount = builtins.length (builtins.attrNames active);
      # Every port the hardware has, so the far end of a link can be
      # checked against it.
      portNames = modelPorts.${r.model} or (builtins.attrNames r.ports);
      # Physical topology: one entry per port ref, as a normalized edge.
      links = portDef.links r.ports;
    };

    assertions = name: entity: top:
      portDef.linkAssertions name entity.routeros.ports top;

    verbs = name: entity: top: let
      sw = entity.routeros;
      identity = if sw.identity != null then sw.identity else name;

      mgmt      = top.entities.${sw.mgmtNetwork};
      mgmtVlan  = mgmt.network.vlan;
      mgmtIp    = sw.addresses.${sw.mgmtNetwork}.ipv4;

      # Routes this switch installs, declared as entities. `refsIn.on` is
      # the inverse index — every route whose refs.on points here.
      myRoutes = map (n: top.entities.${n})
        (entity.refsIn.on or []);
      routesFor    = family: builtins.filter (r: r.attrs.family == family) myRoutes;
      mkRouteRow   = r: { inherit (r.attrs) dst gateway disabled; inherit (r.route) comment; };
      defaultDst   = family: if family == "ipv6" then "::/0" else "0.0.0.0/0";
      defaultRoute = family:
        lib.findFirst (r: r.attrs.dst == defaultDst family) null (routesFor family);

      # The network our default route crosses, or null if we have no
      # default route. Null rather than a fallback: a device with nowhere
      # to send unmatched traffic has no egress network, and inventing
      # one would just move the failure somewhere harder to read.
      egressNet =
        let d = defaultRoute "ipv4";
        in if d == null then null else d.refs.over;

      adminKeys = top.conventions.adminSshKeys or [];

      # Address of a relayed network's DHCP server as reachable from this
      # switch: the server's address on the network our default route
      # crosses. Reading the resolved address view means this works
      # whether the server declares that address or derives it from being
      # the network's gateway, so it follows the route when the route
      # moves.
      dhcpServerAddr = netName: let
        serverName = (top.entities.${netName}).attrs.dnsRef;
        server = top.entities.${serverName} or null;
      in
        if serverName == null || server == null || egressNet == null then null
        else ((server.attrs.addresses or {}).${egressNet} or {}).ipv4 or null;

      # Networks this switch holds an L3 interface on. Holding an address
      # on a VLAN is what makes the chip route it — there is no separate
      # "route this VLAN" declaration and no transit-only address.
      addressNetworks = lib.attrNames sw.addresses;

      # A slice of someone else's delegation, if one is offered to us.
      # Both ends read the same entity: the delegating router derives
      # the pool and the route, we derive the client and the addresses.
      myDelegation = lib.findFirst
        (d: (d.refs.to or null) == name) null
        (builtins.filter (e: e.type == "prefix-delegation")
          (builtins.attrValues (top.entities or {})));

      pdPool = "delegated";

      # SVIs that draw a /64 from it: the ones we route v6 for, read
      # from the resolved inverse rather than re-deriving the gateway
      # default. Not the ones we merely hold an address on — whoever
      # sends the RAs owns the prefix, and advertising one we don't route
      # would point hosts at a router that can't carry their traffic.
      pdNetworks = lib.intersectLists
        addressNetworks
        (entity.refsIn.gateway6 or []);

      # Switch-chip ACLs, derived from the forward policy rather than
      # written twice. A network this switch routes whose zone has no
      # `wan = "accept"` must not reach the internet — and iyr cannot
      # enforce that, because by the time the traffic reaches it every
      # switch-routed source shares one interface. The chip can, because
      # it still sees which VLAN the packet arrived on.
      #
      # Three rules per restricted network, in order: permit the
      # internal destinations, then drop. RouterOS stops at the first
      # match, and an empty new-dst-ports is how it spells drop. Nothing
      # here names a dynamic prefix, so a renumber doesn't touch it.
      internalV4 = top.conventions.internalPrefixes or [];
      internalV6 =
        lib.optional ((top.ipv6UlaPrefix or "") != "") "${top.ipv6UlaPrefix}::/48";

      wanDenied = builtins.filter (netName: let
        zone = (top.entities.${netName}).attrs.zone or "";
        policy = (top.policy.${zone} or {}).wan or null;
      in zone != "" && policy != "accept") addressNetworks;

      switchRules = lib.concatMap (netName: let
        vlan = (top.entities.${netName}).network.vlan;
        rule = extra: { switch = sw.primarySwitchChip; vlan_id = vlan; } // extra;
      in
        lib.optionals (vlan != null && sw.primarySwitchChip != null) (
          map (p: rule { dst_address = p; comment = "${netName}: internal v4"; }) internalV4
          ++ map (p: rule { dst_address6 = p; comment = "${netName}: internal v6"; }) internalV6
          ++ [ (rule { new_dst_ports = ""; comment = "${netName}: no route off-site"; }) ]
        )) wanDenied;

      # Largest L3 MTU any network on this switch asks for, and the
      # ethernet frame size that has to carry it: + 4 for the VLAN tag,
      # since a VLAN interface's l2mtu is the parent's minus the tag.
      # Null when nothing wants more than a standard frame, so switches
      # with no jumbo networks emit no l2mtu lines at all.
      maxNetMtu = lib.foldl' lib.max 1500
        (map (n: top.entities.${n}.network.mtu or 1500) addressNetworks);
      portL2mtu = if maxNetMtu > 1500 then maxNetMtu + 4 else null;

      # Port config lookup with default for unassigned hardware ports.
      portCfg = pname: sw.ports.${pname} or portDef.empty;

      # Bond slave → bond name lookup.
      bondSlaveMap = lib.foldlAttrs (acc: bondName: bond:
        builtins.foldl' (a: slave: a // { ${slave} = bondName; }) acc bond.slaves
      ) {} sw.bonds;

      bridgeIface = pname:
        if bondSlaveMap ? ${pname} then bondSlaveMap.${pname} else pname;

      hwPorts = modelPorts.${sw.model} or (builtins.attrNames sw.ports);
      activePorts = builtins.filter (n: portType (portCfg n) != "unused") hwPorts;
      bridgeInterfaces = lib.unique (map bridgeIface activePorts);

      # VLAN membership computation.
      accessPorts = builtins.filter (n: portType (portCfg n) == "access") hwPorts;
      trunkPorts  = builtins.filter (n: portType (portCfg n) == "trunk") hwPorts;
      usedVlans = let
        aVlans = map (n: (portCfg n).vlan) accessPorts;
        tVlans = builtins.concatLists (map (n: (portCfg n).vlans) trunkPorts);
      in lib.sort builtins.lessThan (lib.unique (aVlans ++ tVlans ++ [mgmtVlan]));

      # VLANs the switch holds an L3 address on — the ones whose traffic
      # the CPU must be able to see (see `tagged` in vlanEntry).
      sviVlans = map (netName: (top.entities.${netName}).network.vlan) addressNetworks;

      accessByVlan = let
        pairs = map (pname: { vlan = (portCfg pname).vlan; port = pname; }) accessPorts;
      in builtins.groupBy (p: toString p.vlan) pairs;

      trunkCarriesVlan = pname: vlan: builtins.elem vlan (portCfg pname).vlans;

      vlanEntry = vlan: let
        vStr = toString vlan;
        untagged = if accessByVlan ? ${vStr}
          then lib.unique (map (p: bridgeIface p.port) accessByVlan.${vStr})
          else [];
        tIfaces = lib.unique (builtins.filter (iface:
          builtins.any (tp: bridgeIface tp == iface && trunkCarriesVlan tp vlan) trunkPorts
        ) (map bridgeIface trunkPorts));
        # The bridge itself is a tagged member of every VLAN the switch
        # holds an address on — not just mgmt. Unicast addressed to an SVI
        # is punted to the CPU either way, which is why L3 routing and
        # pings to the SVI work without this and the gap stays invisible.
        # *Flooded* traffic is what needs the membership: without it the
        # CPU never sees a broadcast on that VLAN, which silently breaks
        # /ip dhcp-relay (it has nothing to relay). mgmt is in
        # addressNetworks like any other, so this subsumes the old
        # mgmt-only special case rather than extending it.
        tagged = tIfaces ++ lib.optional (builtins.elem vlan sviVlans) "bridge1";
      in {
        "vlan_ids" = vStr;
        inherit tagged untagged;
      };

      projection = {
        model = sw.model;

        system = {
          inherit identity;
          timezone    = sw.timezone;
          "dns_servers"   = [mgmt.attrs.gateway4];
          "l3_hw_offload" = sw.l3HwOffload;
          ssh = {
            "host_key_type" = "ed25519";
            keys = map (key: { inherit key; user = sw.sshUser; }) adminKeys;
          };
          snmp = { enabled = true; };
        };

        # Switch chips, as rows rather than as a boolean the generator has
        # to turn back into one. A CRS3xx has a Marvell primary plus an
        # auxiliary Atheros; L3 offload belongs to the primary. Naming it
        # here keeps the chip name out of the generator, which has no way
        # to know it and used to guess "switch1".
        "ethernet_switches" = lib.optional (sw.primarySwitchChip != null) {
          name = sw.primarySwitchChip;
          "l3_hw_offload" = sw.l3HwOffload;
        };

        "l3hw_settings" =
          lib.optionalAttrs (sw.l3HwSettings.ipv6Hw != null) {
            "ipv6_hw" = sw.l3HwSettings.ipv6Hw;
          }
          // lib.optionalAttrs (sw.l3HwSettings.icmpReplyOnError != null) {
            "icmp_reply_on_error" = sw.l3HwSettings.icmpReplyOnError;
          };

        # Ethernet-level frame size. Distinct from the L3 `mtu` on each
        # VLAN interface, and this is the one that has to be raised for
        # jumbo to work at all: a VLAN interface's l2mtu is its parent
        # bridge's minus the 4-byte tag, and a bridge's l2mtu is the
        # *minimum* across its members. So one port left at the default
        # caps every VLAN on the bridge, no matter which ports the jumbo
        # traffic actually crosses.
        #
        # Raising it doesn't leak jumbo anywhere: l2mtu only permits
        # larger frames, it doesn't cause them. Hosts size their packets
        # to the L3 MTU, which stays 1500 on every network that didn't
        # ask for more.
        #
        # The ceiling is per-model (`max-l2mtu`, 10218 on the CRS326).
        interfaces = map (pname: {
          name    = pname;
          enabled = true;
        } // lib.optionalAttrs (portL2mtu != null) {
          l2mtu = portL2mtu;
        }) activePorts;

        bonds = lib.mapAttrsToList (bondName: bond: {
          name      = bondName;
          mode      = bond.mode;
          slaves    = bond.slaves;
          "lacp_mode" = bond.lacpMode;
          comment   = bond.comment;
        }) sw.bonds;

        bridge = {
          name            = "bridge1";
          "protocol_mode"     = "none";
          "igmp_snooping"     = sw.bridge.multicast.snooping;
          "multicast_querier" = sw.bridge.multicast.querier;
          "multicast_router"  = sw.bridge.multicast.router;
          "igmp_version"      = sw.bridge.multicast.igmpVersion;
          "mld_version"       = sw.bridge.multicast.mldVersion;
          "vlan_filtering"    = true;
          ports = map (iface: let
            portName = if sw.bonds ? ${iface}
              then builtins.head sw.bonds.${iface}.slaves
              else iface;
            p = portCfg portName;
            mode = portType p;
          in {
            interface = iface;
            pvid      = if mode == "access" then p.vlan else 1;
            comment   =
              if sw.bonds ? ${iface} then
                if sw.bonds.${iface}.comment != null then sw.bonds.${iface}.comment else iface
              else portLabel p;
          }) bridgeInterfaces;
          vlans = map vlanEntry usedVlans;
        };

        "vlan_interfaces" = map (netName: let
          net = top.entities.${netName};
        in {
          interface = "bridge1";
          name      = "vlan${toString net.network.vlan}";
          "vlan_id" = net.network.vlan;
          mtu       = net.network.mtu;
        }) addressNetworks;

        addresses = map (netName: let
          net = top.entities.${netName};
        in {
          address   = "${sw.addresses.${netName}.ipv4}/${toString net.attrs.prefixLen}";
          interface = "vlan${toString net.network.vlan}";
          network   = net.attrs.network4;
        }) addressNetworks;

        # IPv6 addresses follow the same shape, emitted only for
        # networks where an ipv6 entry is set. Prefix is /64 (the
        # network's ULA + per-VLAN subnet via ulaSubnetHex).
        "ipv6_addresses" = lib.flip lib.concatMap addressNetworks (netName: let
          net = top.entities.${netName};
          v6 = sw.addresses.${netName}.ipv6 or null;
          iface = "vlan${toString net.network.vlan}";
        in
          # The ULA, written down and stable.
          lib.optional (v6 != null) {
            address   = "${v6}/64";
            interface = iface;
          }
          # …and a global /64 drawn from the delegation, on the SVIs we
          # route v6 for. Advertised, so hosts SLAAC from it; RouterOS
          # re-derives the address when the upstream prefix moves, so
          # nothing here needs to know what it currently is.
          ++ lib.optional (myDelegation != null && builtins.elem netName pdNetworks) {
            from_pool = pdPool;
            interface = iface;
            advertise = true;
          });

        # DHCP relay, for networks that ask for it. The switch relays from
        # the SVI it already holds on that network to the network's DHCP
        # server, stamping giaddr with its own address there so the server
        # picks the right subnet. Emitted for every addressed network with
        # dhcpRelay set — including ones where the switch isn't the
        # gateway, since relaying is about carrying the request, not about
        # routing the client.
        "dhcp_relays" = lib.flip lib.concatMap addressNetworks (netName: let
          net = top.entities.${netName};
          server = dhcpServerAddr netName;
          localAddr = sw.addresses.${netName}.ipv4 or null;
        in lib.optional
          (net.network.dhcpRelay && server != null && localAddr != null)
          {
            name = "relay-${netName}";
            interface = "vlan${toString net.network.vlan}";
            "dhcp_server"   = [ server ];
            "local_address" = localAddr;
            disabled = false;
          });

        "ipv6_settings" = lib.optionalAttrs (sw.ipv6Forward != null) {
          forwarding = sw.ipv6Forward;
        };

        # A device advertises itself as an IPv6 default router only if it
        # can actually be one. This switch has no ::/0 route, so on every
        # SVI where it holds a v6 address it must say "not a default
        # router" — otherwise hosts pick it up alongside their real
        # gateway and blackhole internet v6 through it.
        #
        # `ra-lifetime=none` sets the router lifetime to zero; the prefix
        # is still advertised, so SLAAC addressing is unaffected. It is
        # only the "use me as a default route" claim that's withdrawn.
        #
        # This used to be pinned to one SVI — whichever `uplinkNetwork`
        # named — which is why the switch is currently advertising a
        # 30-minute router lifetime on storage, lab, the cluster VLANs
        # and mgmt while having no v6 default at all. The condition was
        # never about the uplink; it's about whether we have a route.
        #
        # (No comment emitted: RouterOS `/ipv6 nd` accepts `comment=`
        # but never stores it, so it would be write-only noise. The
        # rationale lives here in source, where operators read it.)
        "ipv6_nd" = lib.optionals (defaultRoute "ipv6" == null)
          (map (netName: {
            interface     = "vlan${toString top.entities.${netName}.network.vlan}";
            "ra_lifetime" = "none";
          }) (builtins.filter
            (n: (sw.addresses.${n}.ipv6 or null) != null)
            addressNetworks));

        "ipv6_dhcp_clients" = lib.optional (myDelegation != null) {
          interface = "vlan${toString (top.entities.${myDelegation.refs.over}).network.vlan}";
          request = "prefix";
          pool_name = pdPool;
          pool_prefix_length = 64;
          # No add-default-route: the v6 default is a route entity like
          # any other, so it stays visible in the fleet data rather than
          # appearing as a side effect of a DHCP option.
          add_default_route = false;
        };

        "switch_rules" = switchRules;
        routes        = map mkRouteRow (routesFor "ipv4");
        "ipv6_routes" = map mkRouteRow (routesFor "ipv6");
      };

      json = builtins.toJSON projection;
      rscName = "${identity}.rsc";
    in {
      config-json = {
        description = "Output the switch configuration as JSON.";
        pure = true;
        impl = json;
      };
      generate-config = {
        description = "Generate complete RouterOS .rsc configuration.";
        impl = ''
routeros-config generate <<'EGREGORE_EOF'
${json}
EGREGORE_EOF'';
      };
      deploy = {
        description = "Deploy config to switch: back up off-box, then reset-configuration + run-after-reset. DESTRUCTIVE — the switch reboots and rebuilds from the generated script. Recovery is the downloaded backup, over serial if need be. Args are passed as extra SSH/SCP options (e.g. -J iyr).";
        impl = ''
          stamp=$(date +%Y%m%d-%H%M%S)
          backup="preflight-${identity}-$stamp"

          echo "Generating ${rscName}..." >&2
          tmpfile=$(mktemp --suffix=.rsc)
          trap "rm -f $tmpfile" EXIT
          routeros-config generate <<'EGREGORE_EOF' > "$tmpfile"
${json}
EGREGORE_EOF

          # Back up before anything else, and pull it off the switch. A
          # copy that only exists on the device it protects isn't a
          # backup — reset keeps files, but a dead flash doesn't.
          echo "Backing up to /tmp/$backup.backup..." >&2
          ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
            "$@" "admin@${mgmtIp}" "/system backup save name=$backup"
          scp -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
            "$@" "admin@${mgmtIp}:/$backup.backup" "/tmp/$backup.backup"

          echo "Uploading ${rscName}..." >&2
          scp -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
            "$@" "$tmpfile" "admin@${mgmtIp}:/${rscName}"

          # keep-users: the script recreates the admin user anyway (it has
          # to, for a factory-fresh switch), but if it halts before
          # getting there, keeping users is the difference between "log
          # in and fix it" and "find a serial cable".
          echo "Resetting configuration (switch will reboot)..." >&2
          ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
            "$@" "admin@${mgmtIp}" \
            "/system/reset-configuration keep-users=yes no-defaults=yes run-after-reset=${rscName}"

          echo "" >&2
          echo "Deploy complete. ${identity} reboots and applies ${rscName}." >&2
          echo "If it comes back wrong, restore with:" >&2
          echo "  scp /tmp/$backup.backup admin@${mgmtIp}:/" >&2
          echo "  ssh admin@${mgmtIp} '/system backup load name=$backup'" >&2'';
      };
    };
  };
}
