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
        description = ''
          The switch's admin account. Device config, not session or
          deployment policy: the routeros projection installs the
          fleet's admin keys on this account, and the generated ssh
          entries name it as User (naming the account that actually
          holds the keys).
        '';
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

    deriveOptions = {
      # Shared capabilities — bare declarations (the full ones live with
      # the owning kind: `address`/`addresses` in host.nix, `label` in
      # site.nix). Same types as the owners'; the module system merges
      # the declarations.
      address = lib.mkOption { type = lib.types.nullOr lib.types.str; };
      addresses = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            ipv4 = lib.mkOption { type = lib.types.nullOr lib.types.str; };
            ipv6 = lib.mkOption { type = lib.types.nullOr lib.types.str; };
            dhcp = lib.mkOption { type = lib.types.bool; };
          };
        });
      };
      label = lib.mkOption { type = lib.types.str; };
      # Switch-shared keys — full declarations (sodola/swos declare
      # them bare).
      platform = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Platform identifier (\"routeros\", \"swos\", \"sodola\").";
      };
      model = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Hardware model (mirrors `<kind>.model`).";
      };
      portCount = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "Number of declared ports.";
      };
      activePortCount = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "Number of ports in use (access or trunk).";
      };
      portNames = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = ''
          Every port the hardware has, so the far end of a link can be
          checked against it. Null = the kind has no port vocabulary
          (presence is what the link checks read).
        '';
      };
      links = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            localPort = lib.mkOption { type = lib.types.str; default = ""; };
            role = lib.mkOption { type = lib.types.str; default = ""; };
            target = lib.mkOption { type = lib.types.str; default = ""; };
            port = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
            nic = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
          };
        });
        default = [ ];
        description = "Physical topology: one entry per port ref, as a normalized edge.";
      };
      ssh = lib.mkOption {
        type = lib.types.nullOr (lib.types.submodule {
          options.user = lib.mkOption {
            type = lib.types.str;
            description = "The device's admin account that holds the fleet's keys.";
          };
        });
        default = null;
        description = ''
          The admin account that holds the fleet's keys (device config —
          see `routeros.sshUser`). The listener itself is the `ssh`
          exposure (declared in data).
        '';
      };
    };

    derive = name: entity: egregore: let
      r = entity.routeros;
      active = lib.filterAttrs (_: p: portType p != "unused") r.ports;
      mgmtAddr = r.addresses.${r.mgmtNetwork}.ipv4 or null;
    in {
      address = mgmtAddr;
      ssh = { user = r.sshUser; };
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

    assertions = name: entity: egregore:
      portDef.linkAssertions name entity.routeros.ports egregore;

  };
}
