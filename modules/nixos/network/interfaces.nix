# Declarative networkd interface topology.
#
# Pure syntactic sugar over systemd-networkd.  Knows nothing about egregore
# or any particular fleet — just bonds, VLANs, bridges, addresses, policy
# routing, and initrd networking as composable building blocks.
#
# Other modules (topology/network.nix, host configs) set these options;
# this module only generates systemd.network config from them.
{
  path = ["psyclyx" "nixos" "network" "interfaces"];
  gate = "always";
  options = { lib, ... }: let
    bondModule = {
      options = {
        slaves = lib.mkOption {
          type = lib.types.either lib.types.str (lib.types.listOf lib.types.str);
          description = "Slave interfaces (glob pattern or explicit list).";
        };
        mode = lib.mkOption { type = lib.types.str; default = "802.3ad"; };
        hashPolicy = lib.mkOption { type = lib.types.str; default = "layer2+3"; };
        miiMonitorSec = lib.mkOption { type = lib.types.str; default = "0.1"; };
        lacpTransmitRate = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
        mac = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Override MAC address for the bond.";
        };
      };
    };

    vlanModule = {
      options = {
        id = lib.mkOption { type = lib.types.int; };
        parent = lib.mkOption { type = lib.types.str; };
      };
    };

    bridgeModule = {
      options = {
        member = lib.mkOption {
          type = lib.types.str;
          description = "Interface to bridge (typically a bond).";
        };
      };
    };

    networkModule = {
      options = {
        addresses = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Static addresses in CIDR notation.";
        };
        gateway = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Default gateway (only used when policyRouting is null).";
        };
        dns = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
        };
        domains = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
        };
        dhcp = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Use DHCP instead of static addressing.";
        };
        ipv6AcceptRA = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        policyRouting = lib.mkOption {
          type = lib.types.nullOr (lib.types.submodule {
            options = {
              table = lib.mkOption { type = lib.types.int; };
              gateway = lib.mkOption { type = lib.types.str; };
              subnet = lib.mkOption {
                type = lib.types.str;
                description = "Subnet CIDR for the direct route in the policy table.";
              };
              priority = lib.mkOption { type = lib.types.int; default = 200; };
            };
          });
          default = null;
          description = "Source-based policy routing for this interface.";
        };
        requiredForOnline = lib.mkOption {
          type = lib.types.str;
          default = "no";
        };
        mac = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
      };
    };
  in {
    bonds = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule bondModule);
      default = {};
    };
    vlans = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule vlanModule);
      default = {};
    };
    bridges = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule bridgeModule);
      default = {};
    };
    networks = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule networkModule);
      default = {};
    };
    initrd = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Bring up a subset of interfaces in initrd.";
      };
      kernelModules = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
      interfaces = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Interface names to bring up in initrd (addresses from networks).";
      };
    };
  };

  config = { cfg, lib, ... }: let
    hasBonds = cfg.bonds != {};
    hasVlans = cfg.vlans != {};
    hasBridges = cfg.bridges != {};
    hasNetworks = cfg.networks != {};
    hasAnything = hasBonds || hasVlans || hasBridges || hasNetworks;

    ipFromCidr = cidr: builtins.head (lib.splitString "/" cidr);

    slaveMatch = bond:
      if builtins.isList bond.slaves
      then lib.concatStringsSep " " bond.slaves
      else bond.slaves;

    # Which VLANs live on a given parent interface.
    vlansOnParent = parent:
      lib.attrNames (lib.filterAttrs (_: v: v.parent == parent) cfg.vlans);

    # Which bridge (if any) absorbs this interface.
    bridgeFor = iface:
      lib.findFirst
        (bname: cfg.bridges.${bname}.member == iface)
        null
        (lib.attrNames cfg.bridges);

    # --- Netdevs ---

    bondNetdevs = lib.mapAttrs' (name: bond:
      lib.nameValuePair "10-${name}" {
        netdevConfig = {
          Name = name;
          Kind = "bond";
        } // lib.optionalAttrs (bond.mac != null) { MACAddress = bond.mac; };
        bondConfig = {
          Mode = bond.mode;
          TransmitHashPolicy = bond.hashPolicy;
          MIIMonitorSec = bond.miiMonitorSec;
        } // lib.optionalAttrs (bond.lacpTransmitRate != null) {
          LACPTransmitRate = bond.lacpTransmitRate;
        };
      }
    ) cfg.bonds;

    vlanNetdevs = lib.mapAttrs' (name: vlan:
      lib.nameValuePair "10-${name}" {
        netdevConfig = { Name = name; Kind = "vlan"; };
        vlanConfig.Id = vlan.id;
      }
    ) cfg.vlans;

    bridgeNetdevs = lib.mapAttrs' (name: _bridge:
      lib.nameValuePair "15-${name}" {
        netdevConfig = { Name = name; Kind = "bridge"; };
      }
    ) cfg.bridges;

    allNetdevs = bondNetdevs // vlanNetdevs // bridgeNetdevs;

    # --- Networks (link-layer wiring) ---

    # Bond slave units.
    bondSlaveUnits = lib.mapAttrs' (name: bond:
      lib.nameValuePair "10-${name}-slaves" {
        matchConfig.Name = slaveMatch bond;
        networkConfig.Bond = name;
        linkConfig.RequiredForOnline = "enslaved";
      }
    ) cfg.bonds;

    # Bond root units — wire VLANs and/or bridge.
    bondRootUnits = lib.mapAttrs' (name: _bond: let
      childVlans = vlansOnParent name;
      bridge = bridgeFor name;
    in lib.nameValuePair "10-${name}" ({
      matchConfig.Name = name;
      linkConfig.RequiredForOnline = "carrier";
    } // lib.optionalAttrs (childVlans != []) {
      networkConfig.VLAN = childVlans;
    } // lib.optionalAttrs (bridge != null) {
      networkConfig.Bridge = bridge;
    })) cfg.bonds;

    # User-defined L3 network units.
    networkUnits = lib.mapAttrs' (ifname: net: let
      hasPR = net.policyRouting != null;
      pr = net.policyRouting;
    in lib.nameValuePair "20-${ifname}" ({
      matchConfig.Name = ifname;
      linkConfig = {
        RequiredForOnline = net.requiredForOnline;
      } // lib.optionalAttrs (net.mac != null) {
        MACAddress = net.mac;
      };
    }
    // lib.optionalAttrs (net.addresses != []) { address = net.addresses; }
    // lib.optionalAttrs (net.dns != []) { dns = net.dns; }
    // lib.optionalAttrs (net.domains != []) { domains = net.domains; }
    // lib.optionalAttrs net.dhcp {
      networkConfig = {
        DHCP = "yes";
        IPv6AcceptRA = true;
      };
      dhcpV4Config.UseDomains = true;
      dhcpV6Config.WithoutRA = "solicit";
    }
    // lib.optionalAttrs (!net.dhcp && net.ipv6AcceptRA) {
      networkConfig.IPv6AcceptRA = true;
    }
    // lib.optionalAttrs (net.gateway != null && !hasPR) {
      routes = [{ Gateway = net.gateway; }];
    }
    // lib.optionalAttrs hasPR {
      routes = [
        { Gateway = pr.gateway; Table = pr.table; }
        { Destination = pr.subnet; Table = pr.table; }
      ];
      routingPolicyRules = [{
        From = "${ipFromCidr (builtins.head net.addresses)}/32";
        Table = pr.table;
        Priority = pr.priority;
      }];
    })) cfg.networks;

    allNetworks = bondSlaveUnits // bondRootUnits // networkUnits;

    # --- Initrd ---

    # Trace which bonds/VLANs are needed for the requested initrd interfaces.
    initrdVlans = lib.filterAttrs
      (name: _: builtins.elem name cfg.initrd.interfaces)
      cfg.vlans;
    initrdBondNames = lib.unique (
      (map (v: v.parent) (lib.attrValues initrdVlans))
      ++ (builtins.filter (name: cfg.bonds ? ${name}) cfg.initrd.interfaces)
    );

    initrdNetdevs =
      # Bond netdevs needed.
      lib.filterAttrs (k: _: builtins.any (b: k == "10-${b}") initrdBondNames) bondNetdevs
      # VLAN netdevs needed.
      // lib.filterAttrs (k: _: builtins.any (v: k == "10-${v}") (lib.attrNames initrdVlans)) vlanNetdevs;

    initrdSlaveUnits =
      lib.filterAttrs (k: _: builtins.any (b: k == "10-${b}-slaves") initrdBondNames) bondSlaveUnits;

    initrdBondRootUnits = builtins.listToAttrs (map (bname:
      let childVlans = lib.attrNames (lib.filterAttrs (_: v: v.parent == bname) initrdVlans);
      in lib.nameValuePair "10-${bname}" ({
        matchConfig.Name = bname;
        linkConfig.RequiredForOnline = "carrier";
      } // lib.optionalAttrs (childVlans != []) {
        networkConfig.VLAN = childVlans;
      })
    ) initrdBondNames);

    # Initrd network units — addresses from cfg.networks for requested interfaces.
    initrdNetworkUnits = builtins.listToAttrs (builtins.filter (x: x != null) (map (ifname: let
      net = cfg.networks.${ifname} or null;
    in if net == null then null
       else lib.nameValuePair "20-${ifname}" {
         matchConfig.Name = ifname;
         address = net.addresses;
         routes = lib.optional (net.gateway != null) { Gateway = net.gateway; };
         linkConfig.RequiredForOnline = "routable";
       }
    ) cfg.initrd.interfaces));

  in lib.mkIf hasAnything {
    systemd.network.netdevs = allNetdevs;
    systemd.network.networks = allNetworks;

    boot.initrd = lib.mkIf cfg.initrd.enable {
      kernelModules = cfg.initrd.kernelModules;
      systemd.network.netdevs = initrdNetdevs;
      systemd.network.networks =
        initrdSlaveUnits // initrdBondRootUnits // initrdNetworkUnits;
    };
  };
}
