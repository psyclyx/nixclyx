{
  path = ["psyclyx" "topology"];
  gate = false;
  options = {lib, ...}: let
    vpnPeerModule = {
      options = {
        address = lib.mkOption {
          type = lib.types.str;
          description = "WireGuard VPN address (without prefix length)";
        };
        publicKey = lib.mkOption {
          type = lib.types.str;
          description = "WireGuard public key";
        };
        exportedRoutes = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Subnets reachable through this peer (added to hub's AllowedIPs)";
        };
      };
    };

    hostModule = {
      options = {
        vpn = lib.mkOption {
          type = lib.types.nullOr (lib.types.submodule vpnPeerModule);
          default = null;
          description = "VPN configuration for this host (null if not a VPN peer)";
        };
        publicIPv4 = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Public IPv4 address";
        };
        publicIPv6 = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Public IPv6 address";
        };
        sshPort = lib.mkOption {
          type = lib.types.port;
          default = 22;
          description = "SSH listen port";
        };
        nat = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {};
          description = "1:1 NAT mappings: network name → NAT prefix (e.g. rack-vpn → 10.157.10.0/24)";
        };
        labIndex = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "Numeric lab server index (used to derive IP addresses as base + labIndex)";
        };
        mac = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {};
          description = "MAC addresses keyed by interface name";
        };
      };
    };

    networkModule = {
      options = {
        vlan = lib.mkOption {
          type = lib.types.int;
          description = "VLAN ID";
        };
        ipv4 = lib.mkOption {
          type = lib.types.str;
          description = "IPv4 subnet in CIDR notation";
        };
        ipv6Suffix = lib.mkOption {
          type = lib.types.str;
          description = "IPv6 subnet ID suffix (hex, appended to ULA prefix)";
        };
        labIface = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Lab server interface connected to this network (null if no lab hosts on this network)";
        };
        ipv6PdSubnetId = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "DHCPv6 prefix delegation subnet ID";
        };
      };
    };

    linkModule = {
      options = {
        from = lib.mkOption {
          type = lib.types.str;
          description = "Source device";
        };
        to = lib.mkOption {
          type = lib.types.str;
          description = "Destination device";
        };
        port = lib.mkOption {
          type = lib.types.str;
          description = "Port on destination device";
        };
        networks = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "Tagged networks on this link";
        };
        untagged = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Untagged network on this link";
        };
      };
    };
  in {
    conventions = lib.mkOption {
      type = lib.types.submodule {
        options = {
          gatewayOffset = lib.mkOption {
            type = lib.types.int;
            description = "Host offset for gateway addresses within a subnet";
          };
          hostBaseOffset = lib.mkOption {
            type = lib.types.int;
            description = "Base offset for host addresses (lab servers get base + index)";
          };
          dhcpPool = lib.mkOption {
            type = lib.types.submodule {
              options = {
                start = lib.mkOption {
                  type = lib.types.int;
                  description = "First address in DHCP pool (last octet)";
                };
                end = lib.mkOption {
                  type = lib.types.int;
                  description = "Last address in DHCP pool (last octet)";
                };
              };
            };
            description = "DHCP pool address range";
          };
          transitVlan = lib.mkOption {
            type = lib.types.int;
            description = "VLAN ID for the transit (upstream) network";
          };
          homeDomain = lib.mkOption {
            type = lib.types.str;
            description = "Home domain suffix for zone names";
          };
        };
      };
      description = "Network naming and numbering conventions";
    };

    domain = lib.mkOption {
      type = lib.types.submodule {
        options = {
          internal = lib.mkOption {
            type = lib.types.str;
            description = "Internal domain for VPN-resolved names";
          };
          public = lib.mkOption {
            type = lib.types.str;
            description = "Public-facing domain";
          };
        };
      };
      description = "Domain names";
    };

    vpn = lib.mkOption {
      type = lib.types.submodule {
        options = {
          subnet = lib.mkOption {
            type = lib.types.str;
            description = "VPN subnet in CIDR notation";
          };
          port = lib.mkOption {
            type = lib.types.port;
            description = "WireGuard listen port";
          };
          hub = lib.mkOption {
            type = lib.types.str;
            description = "Hostname of the VPN hub";
          };
        };
      };
      description = "VPN overlay configuration";
    };

    uplink = lib.mkOption {
      type = lib.types.submodule {
        options = {
          switch = lib.mkOption {
            type = lib.types.str;
            description = "Switch carrying the upstream link";
          };
          port = lib.mkOption {
            type = lib.types.str;
            description = "Port on the switch connected to upstream";
          };
          vlan = lib.mkOption {
            type = lib.types.int;
            description = "VLAN ID for the upstream transit link";
          };
        };
      };
      description = "Upstream / transit link definition";
    };

    hosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule hostModule);
      default = {};
      description = "Host definitions";
    };

    ipv6UlaPrefix = lib.mkOption {
      type = lib.types.str;
      description = "IPv6 ULA prefix for home network";
    };

    switches = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        freeformType = lib.types.attrsOf lib.types.anything;
        options = {
          model = lib.mkOption {
            type = lib.types.str;
            description = "Switch model identifier";
          };
          mac = lib.mkOption {
            type = lib.types.str;
            description = "Switch base MAC address";
          };
          identity = lib.mkOption {
            type = lib.types.str;
            description = "Switch system identity / hostname";
          };
        };
      });
      default = {};
      description = "Physical switch definitions";
    };

    links = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule linkModule);
      default = [];
      description = "Physical link definitions between devices";
    };

    networks = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule networkModule);
      default = {};
      description = "Network segment definitions (VLANs)";
    };
};
}
