# RouterOS platform — option schema (generic, egregore-unaware).
#
# Mirrors the RouterOS menus we manage. Every option is a plain config
# value; a fleet projection is just a module that sets these. The render
# module turns the evaluated `config.routeros` into a `.rsc` script.
{ lib, ... }:
let
  inherit (lib) mkOption types;
  row = options: types.submodule { inherit options; };
in {
  options.system.build = mkOption {
    type = types.attrsOf types.package;
    default = { };
    description = "Build targets (the `.rsc`, the JSON view) — the analogue of a NixOS `system.build`.";
  };
  options.routeros = mkOption {
    default = { };
    type = types.submodule ({ ... }: {
      options = {
        model = mkOption { type = types.str; default = ""; };
        identity = mkOption { type = types.str; default = ""; };
        timezone = mkOption { type = types.str; default = "America/Los_Angeles"; };

        system = mkOption {
          type = row {
            dnsServers = mkOption { type = types.listOf types.str; default = [ ]; };
            l3HwOffload = mkOption { type = types.bool; default = false; };
            sshKeys = mkOption {
              type = types.listOf (row {
                key = mkOption { type = types.str; };
                user = mkOption { type = types.str; default = "admin"; };
              });
              default = [ ];
            };
            snmp.enable = mkOption { type = types.bool; default = true; };
          };
          default = { };
        };

        # Per-chip L3 offload. A CRS3xx has a Marvell primary plus an
        # auxiliary Atheros; L3 offload belongs to the primary, named here.
        ethernetSwitches = mkOption {
          type = types.listOf (row {
            name = mkOption { type = types.str; };
            l3HwOffload = mkOption { type = types.bool; default = false; };
          });
          default = [ ];
        };

        l3hwSettings = mkOption {
          type = row {
            ipv6Hw = mkOption { type = types.nullOr types.bool; default = null; };
            icmpReplyOnError = mkOption { type = types.nullOr types.bool; default = null; };
          };
          default = { };
        };

        interfaces = mkOption {
          type = types.listOf (row {
            name = mkOption { type = types.str; };
            enabled = mkOption { type = types.bool; default = true; };
            l2mtu = mkOption { type = types.nullOr types.int; default = null; };
          });
          default = [ ];
        };

        bonds = mkOption {
          type = types.listOf (row {
            name = mkOption { type = types.str; };
            mode = mkOption { type = types.str; default = "802.3ad"; };
            slaves = mkOption { type = types.listOf types.str; default = [ ]; };
            lacpMode = mkOption { type = types.nullOr types.str; default = null; };
            comment = mkOption { type = types.nullOr types.str; default = null; };
          });
          default = [ ];
        };

        bridge = mkOption {
          type = row {
            name = mkOption { type = types.str; default = "bridge1"; };
            protocolMode = mkOption { type = types.str; default = "none"; };
            vlanFiltering = mkOption { type = types.bool; default = true; };
            igmpSnooping = mkOption { type = types.bool; default = false; };
            multicastQuerier = mkOption { type = types.bool; default = false; };
            multicastRouter = mkOption { type = types.nullOr types.str; default = null; };
            igmpVersion = mkOption { type = types.nullOr types.int; default = null; };
            mldVersion = mkOption { type = types.nullOr types.int; default = null; };
            ports = mkOption {
              type = types.listOf (row {
                interface = mkOption { type = types.str; };
                pvid = mkOption { type = types.int; default = 1; };
                comment = mkOption { type = types.nullOr types.str; default = null; };
              });
              default = [ ];
            };
            vlans = mkOption {
              type = types.listOf (row {
                vlanIds = mkOption { type = types.str; };
                tagged = mkOption { type = types.listOf types.str; default = [ ]; };
                untagged = mkOption { type = types.listOf types.str; default = [ ]; };
              });
              default = [ ];
            };
          };
          default = { };
        };

        vlanInterfaces = mkOption {
          type = types.listOf (row {
            interface = mkOption { type = types.str; default = "bridge1"; };
            name = mkOption { type = types.str; };
            vlanId = mkOption { type = types.int; };
            mtu = mkOption { type = types.int; default = 1500; };
          });
          default = [ ];
        };

        addresses = mkOption {
          type = types.listOf (row {
            address = mkOption { type = types.str; };
            interface = mkOption { type = types.str; };
            network = mkOption { type = types.nullOr types.str; default = null; };
          });
          default = [ ];
        };

        ipv6Addresses = mkOption {
          type = types.listOf (row {
            interface = mkOption { type = types.str; };
            address = mkOption { type = types.nullOr types.str; default = null; };
            fromPool = mkOption { type = types.nullOr types.str; default = null; };
            advertise = mkOption { type = types.nullOr types.bool; default = null; };
          });
          default = [ ];
        };

        dhcpRelays = mkOption {
          type = types.listOf (row {
            name = mkOption { type = types.str; };
            interface = mkOption { type = types.str; };
            dhcpServer = mkOption { type = types.listOf types.str; };
            localAddress = mkOption { type = types.str; };
            disabled = mkOption { type = types.bool; default = false; };
          });
          default = [ ];
        };

        ipv6Settings.forwarding = mkOption { type = types.nullOr types.bool; default = null; };

        ipv6Nd = mkOption {
          type = types.listOf (row {
            interface = mkOption { type = types.str; };
            raLifetime = mkOption { type = types.nullOr types.str; default = null; };
          });
          default = [ ];
        };

        ipv6DhcpClients = mkOption {
          type = types.listOf (row {
            interface = mkOption { type = types.str; };
            request = mkOption { type = types.str; default = "prefix"; };
            poolName = mkOption { type = types.str; };
            poolPrefixLength = mkOption { type = types.int; default = 64; };
            addDefaultRoute = mkOption { type = types.bool; default = false; };
          });
          default = [ ];
        };

        switchRules = mkOption {
          type = types.listOf (row {
            switch = mkOption { type = types.nullOr types.str; default = null; };
            vlanId = mkOption { type = types.int; };
            srcAddress = mkOption { type = types.nullOr types.str; default = null; };
            dstAddress = mkOption { type = types.nullOr types.str; default = null; };
            srcAddress6 = mkOption { type = types.nullOr types.str; default = null; };
            dstAddress6 = mkOption { type = types.nullOr types.str; default = null; };
            protocol = mkOption { type = types.nullOr types.str; default = null; };
            dstPort = mkOption { type = types.nullOr types.int; default = null; };
            newDstPorts = mkOption { type = types.nullOr types.str; default = null; };
            comment = mkOption { type = types.nullOr types.str; default = null; };
          });
          default = [ ];
        };

        routes = mkOption {
          type = types.listOf (row {
            dst = mkOption { type = types.str; };
            gateway = mkOption { type = types.nullOr types.str; default = null; };
            disabled = mkOption { type = types.bool; default = false; };
            comment = mkOption { type = types.nullOr types.str; default = null; };
          });
          default = [ ];
        };

        ipv6Routes = mkOption {
          type = types.listOf (row {
            dst = mkOption { type = types.str; };
            gateway = mkOption { type = types.nullOr types.str; default = null; };
            disabled = mkOption { type = types.bool; default = false; };
            comment = mkOption { type = types.nullOr types.str; default = null; };
          });
          default = [ ];
        };
      };
    });
  };
}
