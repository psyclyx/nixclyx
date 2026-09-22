# SwOS platform — option schema (generic, egregore-unaware).
#
# Mirrors the SwOS backup document: a list of per-port rows (in the
# device's index order), the VLAN table, and the flat system block. A
# fleet projection sets these; the render module emits the `.swb`.
{ lib, ... }:
let
  inherit (lib) mkOption types;
in {
  options.system.build = mkOption {
    type = types.attrsOf types.package;
    default = { };
  };
  options.swosJson = mkOption {
    type = types.anything;
    default = { };
    internal = true;
    description = "The assembled desired-state document, as a value.";
  };
  options.swos = mkOption {
    default = { };
    type = types.submodule {
      options = {
        identity = mkOption { type = types.str; default = ""; };
        password = mkOption { type = types.str; default = ""; };

        ports = mkOption {
          type = types.listOf (types.submodule {
            options = {
              autoNegotiate = mkOption { type = types.bool; default = true; };
              blocked = mkOption { type = types.bool; default = false; };
              cableMode = mkOption { type = types.int; default = 0; };
              defaultVid = mkOption { type = types.int; default = 1; };
              duplex = mkOption { type = types.bool; default = true; };
              enabled = mkOption { type = types.bool; default = false; };
              flowControlRx = mkOption { type = types.bool; default = false; };
              flowControlTx = mkOption { type = types.bool; default = true; };
              forwardMulticast = mkOption { type = types.bool; default = true; };
              forwardTo = mkOption { type = types.listOf types.int; default = [ ]; };
              ingressRate = mkOption { type = types.int; default = 0; };
              inputMirror = mkOption { type = types.bool; default = false; };
              lacpGroup = mkOption { type = types.int; default = 0; };
              lacpMode = mkOption { type = types.int; default = 0; };
              macLock = mkOption { type = types.bool; default = false; };
              macLockFilter = mkOption { type = types.bool; default = false; };
              name = mkOption { type = types.str; default = ""; };
              outputMirror = mkOption { type = types.bool; default = false; };
              qosType = mkOption { type = types.int; default = 0; };
              sfp = mkOption { type = types.bool; default = false; };
              sourceUnknown = mkOption { type = types.bool; default = false; };
              speed = mkOption { type = types.int; default = 0; };
              stormRate = mkOption { type = types.int; default = 100; };
              vlanMode = mkOption { type = types.int; default = 0; };
              vlanReceive = mkOption { type = types.int; default = 0; };
            };
          });
          default = [ ];
        };

        vlans = mkOption {
          type = types.listOf (types.submodule {
            options = {
              id = mkOption { type = types.int; };
              igmp = mkOption { type = types.bool; default = false; };
              learning = mkOption { type = types.bool; default = true; };
              members = mkOption { type = types.listOf types.int; default = [ ]; };
              mirror = mkOption { type = types.bool; default = false; };
              name = mkOption { type = types.str; default = ""; };
              portIsolation = mkOption { type = types.bool; default = false; };
            };
          });
          default = [ ];
        };

        system = mkOption {
          type = types.submodule {
            options = {
              adminVlan = mkOption { type = types.int; };
              allPorts = mkOption { type = types.listOf types.int; default = [ ]; };
              allowFromAllAddresses = mkOption { type = types.bool; default = false; };
              allowFromAllMgmt = mkOption { type = types.bool; default = false; };
              autoInfo = mkOption { type = types.bool; default = true; };
              discovery = mkOption { type = types.bool; default = true; };
              dropTagged = mkOption { type = types.listOf types.int; default = [ ]; };
              frameSizeCheck = mkOption { type = types.bool; default = false; };
              identity = mkOption { type = types.str; default = ""; };
              igmpFlood = mkOption { type = types.bool; default = false; };
              igmpQuery = mkOption { type = types.bool; default = true; };
              igmpSnooping = mkOption { type = types.bool; default = false; };
              igmpVlanExclusive = mkOption { type = types.bool; default = true; };
              ip = mkOption { type = types.str; default = ""; };
              ipType = mkOption { type = types.int; default = 1; };
              ivl = mkOption { type = types.bool; default = false; };
              management = mkOption { type = types.bool; default = true; };
              poe = mkOption { type = types.bool; default = false; };
              portDiscovery = mkOption { type = types.listOf types.int; default = [ ]; };
              stpCostMode = mkOption { type = types.int; default = 0; };
              stpPriority = mkOption { type = types.int; default = 32768; };
              watchdog = mkOption { type = types.bool; default = true; };
            };
          };
          default = { };
        };

        snmp = mkOption {
          type = types.submodule {
            options = {
              community = mkOption { type = types.str; default = "public"; };
              contact = mkOption { type = types.str; default = ""; };
              enabled = mkOption { type = types.bool; default = true; };
              location = mkOption { type = types.str; default = ""; };
            };
          };
          default = { };
        };

        rstp = mkOption {
          type = types.submodule {
            options.enabledPorts = mkOption { type = types.listOf types.int; default = [ ]; };
          };
          default = { };
        };

        mirror = mkOption {
          type = types.submodule {
            options.targetPort = mkOption { type = types.int; default = 1; };
          };
          default = { };
        };

        filterVid = mkOption { type = types.int; default = 0; };
        acl = mkOption { type = types.listOf types.anything; default = [ ]; };
        hosts = mkOption { type = types.listOf types.anything; default = [ ]; };
      };
    };
  };
}
