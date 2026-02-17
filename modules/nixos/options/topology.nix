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
        network = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Primary network segment name (for lab hosts)";
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
      };
    };
  in {
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

    hosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule hostModule);
      default = {};
      description = "Host definitions";
    };

    ipv6UlaPrefix = lib.mkOption {
      type = lib.types.str;
      description = "IPv6 ULA prefix for home network";
    };

    networks = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule networkModule);
      default = {};
      description = "Network segment definitions (VLANs)";
    };
  };
}
