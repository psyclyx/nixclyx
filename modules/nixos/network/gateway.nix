# Gateway/router networking.
#
# Serves all egregore networks on a LAN trunk with IPv6 RA and DHCPv6
# prefix delegation, plus a WAN transit VLAN with upstream DHCP.
#
# This is the "serve networks" counterpart to topology/network.nix's
# "be on networks" — a host enables one or the other, not both.
#
# Uses the interfaces module for VLAN netdev creation but generates its
# own network units (gateway addresses, RA config, transit DHCP) since
# these are fundamentally different from client-side addressing.
{
  path = ["psyclyx" "nixos" "network" "gateway"];
  description = "Gateway VLAN networking from egregore topology";
  options = { lib, ... }: {
    lanInterface = lib.mkOption {
      type = lib.types.str;
      description = "Physical LAN trunk interface.";
    };
    wanInterface = lib.mkOption {
      type = lib.types.str;
      description = "Physical WAN interface.";
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
    initrdVlans = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Egregore network names to bring up in initrd.";
    };
    initrdKernelModules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["8021q"];
    };
  };
  config = { cfg, config, lib, ... }: let
    eg = config.psyclyx.egregore;

    networks = lib.filterAttrs (_: e: e.type == "network") eg.entities;
    dhcpVlans = lib.sort builtins.lessThan
      (lib.mapAttrsToList (_: e: e.network.vlan) networks);
    vlanNameMap = builtins.listToAttrs (lib.mapAttrsToList (name: e:
      lib.nameValuePair (toString e.network.vlan) name
    ) networks);

    transitVlan = eg.conventions.transitVlan;
    vlanIface = id: "${cfg.lanInterface}.${builtins.toString id}";
    transitIface = "${cfg.wanInterface}.${builtins.toString transitVlan}";

    # Register VLANs via the interfaces module.
    lanVlans = builtins.listToAttrs (map (id:
      lib.nameValuePair (vlanIface id) { inherit id; parent = cfg.lanInterface; }
    ) dhcpVlans);
    transitVlanEntry = {
      ${transitIface} = { id = transitVlan; parent = cfg.wanInterface; };
    };

    # Gateway-specific network units (RA, PD — not expressible via interfaces.networks).
    mkGatewayNetwork = vlanId: let
      name = vlanNameMap.${toString vlanId};
      net = eg.entities.${name};
      na = net.attrs;
      siteEntity = if net.network.site != null then eg.entities.${net.network.site} or null else null;
      siteDomain = if siteEntity != null then siteEntity.site.domain or eg.domains.home else eg.domains.home;
    in lib.nameValuePair "31-${vlanIface vlanId}" {
      matchConfig.Name = vlanIface vlanId;
      address = [
        "${na.gateway4}/${toString na.prefixLen}"
        "${na.gateway6}/64"
      ];
      networkConfig = {
        IPv6SendRA = true;
        DHCPPrefixDelegation = true;
      };
      dhcpPrefixDelegationConfig = {
        SubnetId = net.network.ipv6PdSubnetId;
        Token = "::1";
      };
      ipv6SendRAConfig = {
        Managed = true;
        OtherInformation = true;
        DNS = "_link_local";
        Domains = "${siteDomain} ${na.zoneName} ${eg.domains.internal}";
      };
      ipv6Prefixes = [
        { Prefix = "${eg.ipv6UlaPrefix}:${net.network.ulaSubnetHex}::/64"; }
      ];
      linkConfig.RequiredForOnline = "routable";
    };

    # Initrd VLAN networking.
    initrdVlanIds = map (name: eg.entities.${name}.network.vlan) cfg.initrdVlans;
    mkInitrdVlanNetwork = vlanId: let
      name = vlanNameMap.${toString vlanId};
      na = eg.entities.${name}.attrs;
    in lib.nameValuePair "11-${vlanIface vlanId}" {
      matchConfig.Name = vlanIface vlanId;
      address = ["${na.gateway4}/${toString na.prefixLen}"];
      linkConfig.RequiredForOnline = "routable";
    };
  in {
    # Wire VLANs through the interfaces module.
    psyclyx.nixos.network.interfaces.vlans = lanVlans // transitVlanEntry;

    psyclyx.nixos.boot.initrd-ssh.network = lib.mkIf (cfg.initrdVlans != []) {
      kernelModules = cfg.initrdKernelModules;
      netdevs = builtins.listToAttrs (map (id:
        lib.nameValuePair "11-${vlanIface id}" {
          netdevConfig = { Name = vlanIface id; Kind = "vlan"; };
          vlanConfig.Id = id;
        }
      ) initrdVlanIds);
      networks =
        {
          "10-${cfg.lanInterface}" = {
            matchConfig.Name = cfg.lanInterface;
            networkConfig.DHCP = "no";
            vlan = map vlanIface initrdVlanIds;
            linkConfig.RequiredForOnline = "carrier";
          };
        }
        // builtins.listToAttrs (map mkInitrdVlanNetwork initrdVlanIds);
    };

    systemd.network.config.dhcpV6Config.DUIDType = "link-layer";

    # LAN + WAN trunk wiring (gateway manages these directly, not via interfaces.networks).
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
        vlan = map vlanIface dhcpVlans;
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
    } // builtins.listToAttrs (map mkGatewayNetwork dhcpVlans);
  };
}
