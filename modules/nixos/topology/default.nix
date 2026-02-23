{
  path = ["psyclyx" "topology"];
  gate = "always";
  imports = [./wireguard.nix ./dns.nix ./monitoring.nix ./deployment.nix];
  config = {config, lib, ...}: let
    topo = config.psyclyx.topology;
  in {
    # Populate domains from deprecated fields so existing data keeps working.
    psyclyx.topology.domains = {
      internal = lib.mkDefault topo.domain.internal;
      public = lib.mkDefault topo.domain.public;
      home = lib.mkDefault topo.conventions.homeDomain;
    };

    # Forward deprecated vpn.{port,hub} → wireguard.{port,hub}
    psyclyx.topology.wireguard = {
      port = lib.mkDefault topo.vpn.port;
      hub = lib.mkDefault topo.vpn.hub;
    };
  };
  options = {lib, ...}: let
    # New structured WireGuard peer module (replaces vpnPeerModule)
    wireguardPeerModule = {
      options = {
        publicKey = lib.mkOption {
          type = lib.types.str;
          description = "WireGuard public key";
        };
        endpoint = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Endpoint address:port (hub only)";
        };
        exportedRoutes = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Subnets routable behind this peer";
        };
      };
    };

    # Deprecated: use wireguardPeerModule instead
    vpnPeerModule = {
      options = {
        address = lib.mkOption {
          type = lib.types.str;
          description = "WireGuard VPN address (without prefix length) — deprecated: use addresses.vpn.ipv4";
        };
        publicKey = lib.mkOption {
          type = lib.types.str;
          description = "WireGuard public key — deprecated: use wireguard.publicKey";
        };
        exportedRoutes = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Subnets reachable through this peer — deprecated: use wireguard.exportedRoutes";
        };
      };
    };

    addressModule = {
      options = {
        ipv4 = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "IPv4 address (without prefix length)";
        };
        ipv6 = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "IPv6 address (without prefix length)";
        };
      };
    };

    hostModule = {config, lib, ...}: {
      config = lib.mkIf (config.vpn != null) {
        # Forward deprecated vpn.{publicKey,exportedRoutes} → wireguard.*
        wireguard = lib.mkDefault {
          publicKey = config.vpn.publicKey;
          exportedRoutes = config.vpn.exportedRoutes;
        };
        # Forward deprecated vpn.address → addresses.vpn.ipv4
        addresses.vpn.ipv4 = lib.mkDefault config.vpn.address;
      };
      options = {
        wireguard = lib.mkOption {
          type = lib.types.nullOr (lib.types.submodule wireguardPeerModule);
          default = null;
          description = "WireGuard configuration for this host (null if not a peer)";
        };
        vpn = lib.mkOption {
          type = lib.types.nullOr (lib.types.submodule vpnPeerModule);
          default = null;
          description = "Deprecated: use wireguard + addresses.vpn instead";
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
          description = "1:1 NAT mappings: network name → NAT prefix (e.g. rack → 10.157.10.0/24)";
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
        addresses = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule addressModule);
          default = {};
          description = "Per-network address overrides. Null fields = derived from conventions.";
        };
        interfaces = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule {
            options = {
              bond = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Bond interface name (e.g. bond0). Null if using a raw device.";
              };
              members = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [];
                description = "Physical interfaces that are members of the bond.";
              };
              device = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Raw device name when not using a bond (e.g. eno1).";
              };
            };
          });
          default = {};
          description = "Per-network interface mapping (bond or raw device).";
        };
        roles = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Informational roles for this host (e.g. server, workstation, router).";
        };
        services = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule {
            options = {
              port = lib.mkOption {
                type = lib.types.port;
                description = "Port number this service listens on.";
              };
              networks = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [];
                description = "Networks this service is reachable on. Empty = all host networks.";
              };
            };
          });
          default = {};
          description = "Services this host exports (for monitoring, DNS, firewall).";
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
          transitVlan = lib.mkOption {
            type = lib.types.int;
            description = "VLAN ID for the transit (upstream) network";
          };
          homeDomain = lib.mkOption {
            type = lib.types.str;
            description = "Home domain suffix for zone names (deprecated: use domains.home)";
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
            description = "Internal domain for VPN-resolved names (deprecated: use domains.internal)";
          };
          public = lib.mkOption {
            type = lib.types.str;
            description = "Public-facing domain (deprecated: use domains.public)";
          };
        };
      };
      description = "Domain names (deprecated: use domains)";
    };

    domains = lib.mkOption {
      type = lib.types.submodule {
        options = {
          internal = lib.mkOption {
            type = lib.types.str;
            description = "Internal domain for VPN-resolved names";
          };
          public = lib.mkOption {
            type = lib.types.str;
            description = "Public-facing / internet-facing domain";
          };
          home = lib.mkOption {
            type = lib.types.str;
            description = "Per-network local zone suffix (home/lab DNS)";
          };
        };
      };
      description = "Unified domain names block";
    };

    wireguard = lib.mkOption {
      type = lib.types.submodule {
        options = {
          port = lib.mkOption {
            type = lib.types.port;
            default = 51820;
            description = "WireGuard listen port";
          };
          hub = lib.mkOption {
            type = lib.types.str;
            description = "Hostname of the WireGuard hub";
          };
        };
      };
      description = "WireGuard overlay configuration";
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
            description = "WireGuard listen port — deprecated: use wireguard.port";
          };
          hub = lib.mkOption {
            type = lib.types.str;
            description = "Hostname of the VPN hub — deprecated: use wireguard.hub";
          };
        };
      };
      description = "VPN overlay configuration — deprecated: use wireguard";
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
          mgmt = lib.mkOption {
            type = lib.types.nullOr (lib.types.submodule {
              options = {
                network = lib.mkOption {
                  type = lib.types.str;
                  description = "Management network name";
                };
                ipv4 = lib.mkOption {
                  type = lib.types.str;
                  description = "Management IPv4 address";
                };
              };
            });
            default = null;
            description = "Management interface (network + address)";
          };
          bridge = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Bridge interface name";
          };
          addresses = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule {
              options = {
                address = lib.mkOption {
                  type = lib.types.str;
                  description = "IP address in CIDR notation";
                };
                vlan = lib.mkOption {
                  type = lib.types.nullOr lib.types.int;
                  default = null;
                  description = "VLAN ID (null for untagged)";
                };
              };
            });
            default = {};
            description = "Switch IP addresses keyed by interface/VLAN name";
          };
          portRenames = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = {};
            description = "Port name mappings (original → short name)";
          };
          bonds = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule {
              options = {
                slaves = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  description = "Member ports in this bond";
                };
                mode = lib.mkOption {
                  type = lib.types.str;
                  description = "Bond mode (e.g. 802.3ad)";
                };
                lacpPassive = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Whether LACP is passive on this bond";
                };
                comment = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Human-readable description";
                };
              };
            });
            default = {};
            description = "Bond definitions";
          };
          ports = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule {
              options = {
                pvid = lib.mkOption {
                  type = lib.types.nullOr lib.types.int;
                  default = null;
                  description = "Port VLAN ID (untagged VLAN)";
                };
                tagged = lib.mkOption {
                  type = lib.types.listOf lib.types.int;
                  default = [];
                  description = "Tagged VLANs on this port";
                };
                comment = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Human-readable description";
                };
              };
            });
            default = {};
            description = "Per-port VLAN membership";
          };
          ssh = lib.mkOption {
            type = lib.types.nullOr (lib.types.submodule {
              options = {
                forwardingEnabled = lib.mkOption {
                  type = lib.types.str;
                  description = "SSH forwarding mode (both, local, no)";
                };
                hostKeyType = lib.mkOption {
                  type = lib.types.str;
                  description = "SSH host key type (e.g. ed25519)";
                };
              };
            });
            default = null;
            description = "SSH configuration for switch management";
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
