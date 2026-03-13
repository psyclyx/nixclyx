{
  path = ["psyclyx" "topology"];
  gate = "always";
  imports = [./enrichment.nix ./validation.nix ./wireguard.nix ./dns.nix ./monitoring.nix ./deployment.nix ./dhcp.nix ./ha.nix];
  config = {};
  options = {lib, ...}: let
    haGroupServiceModule = {
      options = {
        port = lib.mkOption {
          type = lib.types.port;
          description = "Frontend port the HA proxy listens on.";
        };
        backendPort = lib.mkOption {
          type = lib.types.nullOr lib.types.port;
          default = null;
          description = "Backend port on members (defaults to frontend port if null).";
        };
        mode = lib.mkOption {
          type = lib.types.enum ["http" "tcp"];
          default = "http";
          description = "HAProxy mode (http or tcp).";
        };
        check = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "HTTP health check path (null = TCP check only).";
        };
        checkPort = lib.mkOption {
          type = lib.types.nullOr lib.types.port;
          default = null;
          description = "Port for health checks if different from backend port.";
        };
      };
    };

    haGroupModule = {
      options = {
        network = lib.mkOption {
          type = lib.types.str;
          description = "Topology network this HA group operates on.";
        };
        vipOffset = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "Host offset for the virtual IP (deprecated, use vip).";
        };
        vip = lib.mkOption {
          type = lib.types.nullOr (lib.types.submodule {
            options = {
              ipv4 = lib.mkOption {
                type = lib.types.str;
                description = "Virtual IP address (IPv4).";
              };
              ipv6 = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Virtual IP address (IPv6).";
              };
            };
          });
          default = null;
          description = "Explicit VIP address (preferred over vipOffset derivation).";
        };
        vrid = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "VRRP ID for keepalived (defaults to vipOffset if null).";
        };
        members = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "Hostnames of cluster members.";
        };
        services = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule haGroupServiceModule);
          default = {};
          description = "Services fronted by this HA group.";
        };
      };
    };

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

    hostModule = {
      options = {
        wireguard = lib.mkOption {
          type = lib.types.nullOr (lib.types.submodule wireguardPeerModule);
          default = null;
          description = "WireGuard configuration for this host (null if not a peer)";
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
        kind = lib.mkOption {
          type = lib.types.enum ["physical" "vm" "container" "cloud"];
          default = "physical";
          description = "Device kind — determines which config backend and capabilities apply.";
        };
        parent = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Parent host (for VMs/containers — which host this runs on).";
        };
        hardware = lib.mkOption {
          type = lib.types.submodule {
            options.tpm = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Whether this host has a TPM 2.0 module installed.";
            };
          };
          default = {};
          description = "Hardware capabilities.";
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
        ipv6PdSubnetId = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "DHCPv6 prefix delegation subnet ID";
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
          transitVlan = lib.mkOption {
            type = lib.types.int;
            description = "VLAN ID for the transit (upstream) network";
          };
        };
      };
      description = "Network naming and numbering conventions";
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
          subnet = lib.mkOption {
            type = lib.types.str;
            description = "WireGuard VPN subnet in CIDR notation";
          };
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

    haGroups = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule haGroupModule);
      default = {};
      description = "High-availability groups (keepalived VIP + haproxy).";
    };
  };
}
