# Gateway/router networking — generic NixOS sugar.
#
# Takes flat option data (the networks this host gateways, per-VLAN
# addresses, RA domains, static routes, etc.) and emits the
# corresponding networkd config (RA, DHCPv6-PD on each LAN VLAN,
# upstream DHCP on the WAN transit VLAN). Does NOT read egregore —
# `modules/nixos/topology/gateway.nix` is the projection that
# populates this module's options from fleet data.
{
  path = ["psyclyx" "nixos" "network" "gateway"];
  description = "Gateway VLAN networking (RA + DHCPv6-PD per VLAN, WAN transit)";
  options = { lib, ... }: let
    netModule = lib.types.submodule {
      options = {
        id = lib.mkOption {
          type = lib.types.int;
          description = "VLAN id on lanInterface.";
        };
        address4 = lib.mkOption {
          type = lib.types.str;
          description = "IPv4 address in CIDR notation (the gateway IP).";
        };
        address6 = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "IPv6 address in CIDR notation.";
        };
        ulaPrefix = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "ULA prefix advertised in RA, e.g. fd9a:e830:4b1e:a::/64.";
        };
        pdSubnetId = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "Subnet id for DHCPv6 prefix delegation on this VLAN.";
        };
        raDomains = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Domains advertised via RA option (DNSSL).";
        };
        staticRoutes = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule {
            options = {
              destination = lib.mkOption { type = lib.types.str; };
              gateway = lib.mkOption { type = lib.types.str; };
            };
          });
          default = [];
          description = ''
            Static routes to install on this VLAN's network unit. Used
            for switch-routed sibling VLANs whose next hop sits on this
            VLAN, so connected clients reach those subnets directly.
          '';
        };
      };
    };

    initrdNetModule = lib.types.submodule {
      options = {
        id = lib.mkOption {
          type = lib.types.int;
        };
        address4 = lib.mkOption {
          type = lib.types.str;
          description = "IPv4 address in CIDR notation for initrd reachability.";
        };
      };
    };
  in {
    lanInterface = lib.mkOption {
      type = lib.types.str;
      description = "Physical LAN trunk interface.";
    };
    wanInterface = lib.mkOption {
      type = lib.types.str;
      description = "Physical WAN interface.";
    };
    transitVlan = lib.mkOption {
      type = lib.types.int;
      description = "VLAN id of the WAN transit subinterface on wanInterface.";
    };
    transitDhcpV6 = {
      prefixDelegationHint = lib.mkOption {
        type = lib.types.str;
        default = "::/60";
      };
      iaid = lib.mkOption {
        type = lib.types.int;
        default = 250;
      };
      duidRawData = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
    };
    lanAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Static address on the untagged LAN interface.";
    };
    lanMac = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    wanMac = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    networks = lib.mkOption {
      type = lib.types.listOf netModule;
      default = [];
      description = ''
        Networks this host gateways. Populated by topology/gateway.nix
        from egregore data; can also be set directly when no fleet
        framework is involved.
      '';
    };
    initrd = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Bring the listed networks up in initrd.";
      };
      kernelModules = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["8021q"];
      };
      networks = lib.mkOption {
        type = lib.types.listOf initrdNetModule;
        default = [];
        description = "Gateway VLANs to bring up before stage-2.";
      };
    };
  };

  config = { cfg, lib, ... }: let
    vlanIface = id: "${cfg.lanInterface}.${builtins.toString id}";
    transitIface = "${cfg.wanInterface}.${builtins.toString cfg.transitVlan}";

    # Register every gateway-served VLAN as a netdev via the interfaces
    # module so the trunk's `vlan = [...]` list is consistent.
    lanVlans = builtins.listToAttrs (map (net:
      lib.nameValuePair (vlanIface net.id) {
        id = net.id;
        parent = cfg.lanInterface;
      }
    ) cfg.networks);
    transitVlanEntry = {
      ${transitIface} = { id = cfg.transitVlan; parent = cfg.wanInterface; };
    };

    mkGatewayNetwork = net: lib.nameValuePair "31-${vlanIface net.id}" ({
      matchConfig.Name = vlanIface net.id;
      address =
        [ net.address4 ]
        ++ lib.optional (net.address6 != null) net.address6;
      networkConfig = {
        IPv6SendRA = true;
        DHCPPrefixDelegation = net.pdSubnetId != null;
      };
      ipv6SendRAConfig = {
        Managed = true;
        OtherInformation = true;
        DNS = "_link_local";
        Domains = lib.concatStringsSep " " net.raDomains;
      };
      linkConfig.RequiredForOnline = "routable";
    } // lib.optionalAttrs (net.pdSubnetId != null) {
      dhcpPrefixDelegationConfig = {
        SubnetId = net.pdSubnetId;
        Token = "::1";
      };
    } // lib.optionalAttrs (net.ulaPrefix != null) {
      ipv6Prefixes = [ { Prefix = net.ulaPrefix; } ];
    } // lib.optionalAttrs (net.staticRoutes != []) {
      routes = map (r: { Destination = r.destination; Gateway = r.gateway; }) net.staticRoutes;
    });

    mkInitrdVlanNetwork = net: lib.nameValuePair "11-${vlanIface net.id}" {
      matchConfig.Name = vlanIface net.id;
      address = [ net.address4 ];
      linkConfig.RequiredForOnline = "routable";
    };
  in {
    psyclyx.nixos.network.interfaces.vlans = lanVlans // transitVlanEntry;

    psyclyx.nixos.boot.initrd-ssh.network = lib.mkIf cfg.initrd.enable {
      kernelModules = cfg.initrd.kernelModules;
      netdevs = builtins.listToAttrs (map (net:
        lib.nameValuePair "11-${vlanIface net.id}" {
          netdevConfig = { Name = vlanIface net.id; Kind = "vlan"; };
          vlanConfig.Id = net.id;
        }
      ) cfg.initrd.networks);
      networks =
        {
          "10-${cfg.lanInterface}" = {
            matchConfig.Name = cfg.lanInterface;
            networkConfig.DHCP = "no";
            vlan = map (net: vlanIface net.id) cfg.initrd.networks;
            linkConfig.RequiredForOnline = "carrier";
          };
        }
        // builtins.listToAttrs (map mkInitrdVlanNetwork cfg.initrd.networks);
    };

    systemd.network.config.dhcpV6Config.DUIDType = "link-layer";

    systemd.network.networks = {
      "30-${cfg.lanInterface}" = {
        matchConfig.Name = cfg.lanInterface;
        linkConfig = {
          RequiredForOnline = "carrier";
        } // lib.optionalAttrs (cfg.lanMac != null) {
          MACAddress = cfg.lanMac;
        };
        networkConfig = { Domains = ["~."]; DHCP = "no"; };
        address = lib.optional (cfg.lanAddress != null) cfg.lanAddress;
        dns = ["127.0.0.1"];
        vlan = map (net: vlanIface net.id) cfg.networks;
      };
      "30-${cfg.wanInterface}" = {
        matchConfig.Name = cfg.wanInterface;
        linkConfig = {
          RequiredForOnline = "carrier";
        } // lib.optionalAttrs (cfg.wanMac != null) {
          MACAddress = cfg.wanMac;
        };
        networkConfig.DHCP = "no";
        vlan = [transitIface];
      };
      "31-${transitIface}" = {
        matchConfig.Name = transitIface;
        networkConfig = { DHCP = "yes"; IPv6AcceptRA = true; };
        dhcpV4Config = { UseRoutes = true; ClientIdentifier = "duid"; };
        dhcpV6Config = {
          PrefixDelegationHint = cfg.transitDhcpV6.prefixDelegationHint;
          WithoutRA = "solicit";
          UseAddress = false;
          RapidCommit = true;
          IAID = cfg.transitDhcpV6.iaid;
          DUIDType = "uuid";
        } // lib.optionalAttrs (cfg.transitDhcpV6.duidRawData != null) {
          DUIDRawData = cfg.transitDhcpV6.duidRawData;
        };
        routes = [{ Destination = "::/0"; Metric = 1024; }];
        linkConfig.RequiredForOnline = "carrier";
      };
    } // builtins.listToAttrs (map mkGatewayNetwork cfg.networks);
  };
}
