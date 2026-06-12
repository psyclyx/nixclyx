# Entity type: MikroTik RouterOS switch.
{
  egregoreType = { lib, ... }: let
    portDef = import ../lib/switch-port.nix { inherit lib; };
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
          the switch routes (see routedNetworks), they become the network's
          gateway; for other networks they're transit-only interfaces.
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
      uplinkNetwork = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Network whose gateway becomes this switch's IPv4 default route.
          Null = use mgmtNetwork. Set explicitly when the switch is an L3
          router and you want cross-VLAN egress to avoid hairpinning
          through a lower-bandwidth mgmt path.
        '';
      };
      l3HwOffload = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable hardware-offloaded inter-VLAN routing on the bridge.
          Supported on CRS3xx (Marvell Prestera) running RouterOS 7.6+.
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
      routedNetworks = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = ''
          Networks this switch is the L3 gateway for. Explicit entries are
          unioned with networks whose attrs.gatewayRef points at this
          entity. Routed networks get an /interface vlan + /ip address
          emitted using the switch's matching addresses.<network> entry.
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
      networkEntities = lib.filterAttrs (_: e: e.type == "network") (top.entities or {});
      autoRouted = lib.attrNames (
        lib.filterAttrs (_: net: (net.attrs.gatewayRef or null) == name) networkEntities
      );
    in {
      address = mgmtAddr;
      label = "${if r.identity != null then r.identity else name} (${r.model})";
      platform = "routeros";
      model = r.model;
      portCount = builtins.length (builtins.attrNames r.ports);
      activePortCount = builtins.length (builtins.attrNames active);
      routedNetworks = lib.unique (r.routedNetworks ++ autoRouted);
    };

    verbs = name: entity: top: let
      sw = entity.routeros;
      identity = if sw.identity != null then sw.identity else name;

      mgmt      = top.entities.${sw.mgmtNetwork};
      mgmtVlan  = mgmt.network.vlan;
      mgmtIp    = sw.addresses.${sw.mgmtNetwork}.ipv4;

      # Default route derives from the uplink network's gateway. Falls back
      # to mgmt when no uplink override is set.
      uplinkName = if sw.uplinkNetwork != null then sw.uplinkNetwork else sw.mgmtNetwork;
      uplinkNet  = top.entities.${uplinkName};
      uplinkGw   = uplinkNet.attrs.gateway4;

      adminKeys = top.conventions.adminSshKeys or [];

      # All entries in sw.addresses get an L3 interface. Routed networks
      # are the gateway for their subnet; others are transit-only IPs that
      # let the switch participate on the VLAN (e.g. to reach a next-hop).
      addressedNetworks = lib.attrNames sw.addresses;
      routedSet = lib.genAttrs entity.attrs.routedNetworks (_: true);

      # Port config lookup with default for unassigned hardware ports.
      portCfg = pname: sw.ports.${pname} or {
        vlan = null; vlans = []; meta = { host = null; peer = null; description = null; };
      };

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
        tagged = tIfaces ++ (if vlan == mgmtVlan then ["bridge1"] else []);
      in {
        vlan_ids = vStr;
        inherit tagged untagged;
      };

      projection = {
        model = sw.model;

        system = {
          inherit identity;
          timezone    = sw.timezone;
          dns_servers = [mgmt.attrs.gateway4];
          l3_hw_offload = sw.l3HwOffload;
          ssh = {
            host_key_type = "ed25519";
            keys = map (key: { inherit key; user = sw.sshUser; }) adminKeys;
          };
          snmp = { enabled = true; };
        };

        l3hw_settings =
          lib.optionalAttrs (sw.l3HwSettings.ipv6Hw != null) {
            ipv6_hw = sw.l3HwSettings.ipv6Hw;
          }
          // lib.optionalAttrs (sw.l3HwSettings.icmpReplyOnError != null) {
            icmp_reply_on_error = sw.l3HwSettings.icmpReplyOnError;
          };

        interfaces = map (pname: {
          name    = pname;
          enabled = true;
        }) activePorts;

        bonds = lib.mapAttrsToList (bondName: bond: {
          name      = bondName;
          mode      = bond.mode;
          slaves    = bond.slaves;
          lacp_mode = bond.lacpMode;
          comment   = bond.comment;
        }) sw.bonds;

        bridge = {
          name            = "bridge1";
          protocol_mode   = "none";
          igmp_snooping    = sw.bridge.multicast.snooping;
          multicast_querier = sw.bridge.multicast.querier;
          multicast_router  = sw.bridge.multicast.router;
          igmp_version      = sw.bridge.multicast.igmpVersion;
          mld_version       = sw.bridge.multicast.mldVersion;
          vlan_filtering  = true;
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

        vlan_interfaces = map (netName: let
          net = top.entities.${netName};
        in {
          interface = "bridge1";
          name      = "vlan${toString net.network.vlan}";
          vlan_id   = net.network.vlan;
          mtu       = net.network.mtu;
          routed    = routedSet ? ${netName};
        }) addressedNetworks;

        addresses = map (netName: let
          net = top.entities.${netName};
        in {
          address   = "${sw.addresses.${netName}.ipv4}/${toString net.attrs.prefixLen}";
          interface = "vlan${toString net.network.vlan}";
          network   = net.attrs.network4;
        }) addressedNetworks;

        # IPv6 addresses follow the same shape, emitted only for
        # networks where an ipv6 entry is set. Prefix is /64 (the
        # network's ULA + per-VLAN subnet via ulaSubnetHex).
        ipv6_addresses = lib.flip lib.concatMap addressedNetworks (netName: let
          net = top.entities.${netName};
          v6 = sw.addresses.${netName}.ipv6 or null;
        in lib.optional (v6 != null) {
          address   = "${v6}/64";
          interface = "vlan${toString net.network.vlan}";
        });

        ipv6_settings = lib.optionalAttrs (sw.ipv6Forward != null) {
          forwarding = sw.ipv6Forward;
        };

        routes = [{
          # Non-L3 switches keep the default route declared-but-disabled
          # (matches prior behavior — a placeholder operators enable by
          # hand if needed). L3 routers must have it active.
          disabled = !sw.l3HwOffload;
          dst      = "0.0.0.0/0";
          gateway  = uplinkGw;
        }];
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
        impl = ''routeros-config generate <<'EGREGORE_EOF'
${json}
EGREGORE_EOF'';
      };
      deploy = {
        description = "Deploy config to switch (upload + reset-configuration). DESTRUCTIVE — switch reboots and reapplies. Prefer `apply` for incremental changes. Args are passed as extra SSH/SCP options (e.g. -J iyr).";
        impl = ''
          echo "Generating ${rscName}..." >&2
          tmpfile=$(mktemp --suffix=.rsc)
          trap "rm -f $tmpfile" EXIT
          routeros-config generate <<'EGREGORE_EOF' > "$tmpfile"
${json}
EGREGORE_EOF

          echo "Uploading to ${mgmtIp} via SCP..." >&2
          scp -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
            "$@" "$tmpfile" "admin@${mgmtIp}:/${rscName}"

          echo "Resetting configuration (switch will reboot)..." >&2
          ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
            "$@" "admin@${mgmtIp}" \
            "/system/reset-configuration no-defaults=yes run-after-reset=${rscName}"

          echo "Deploy complete. Switch will reboot and apply ${rscName}." >&2'';
      };
      apply = {
        description = "Incremental apply via /export terse diff. Non-destructive: pulls current state, computes diff against desired, pushes only changed items. Diffs only the sections that safely tolerate live add/remove (/interface vlan, /ip address, /interface bridge vlan). Use --dry-run to preview. Extra ssh args pass through as `-- -J jumphost`.";
        impl = ''
          dry_run=""
          while [[ $# -gt 0 && "$1" != "--" ]]; do
            case "$1" in
              --dry-run|-n) dry_run="--dry-run"; shift ;;
              *) echo "unknown arg: $1" >&2; exit 1 ;;
            esac
          done
          [[ "$1" == "--" ]] && shift

          ssh_args=""
          if [[ $# -gt 0 ]]; then
            ssh_args="--ssh-args"
            for a in "$@"; do ssh_args="$ssh_args $a"; done
          fi

          session_id=$(date +%s)-$$
          echo "Applying to ${mgmtIp} (session $session_id)..." >&2
          routeros-config apply $dry_run \
            --session-id "$session_id" \
            "admin@${mgmtIp}" $ssh_args <<'EGREGORE_EOF'
${json}
EGREGORE_EOF
        '';
      };
    };
  };
}
