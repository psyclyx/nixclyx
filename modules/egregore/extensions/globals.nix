# Global configuration — cross-cutting values used by type modules
# and projections. Not entities — context.
{
  options = { lib, ... }: {
    conventions = lib.mkOption {
      type = lib.types.submodule {
        options = {
          gatewayOffset = lib.mkOption {
            type = lib.types.int;
            default = 1;
            description = "Host offset for gateway address within each subnet.";
          };
          transitVlan = lib.mkOption {
            type = lib.types.int;
            default = 250;
            description = "VLAN ID for WAN transit.";
          };
          adminSshKeys = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "SSH public keys for administrative access.";
          };
        };
      };
      default = {};
    };

    domains = lib.mkOption {
      type = lib.types.submodule {
        options = {
          internal = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = ''
              Parent zone for internal-audience services. Subdomains
              resolve via per-site resolver localZones; the wildcard
              cert is issued by the host(s) authoritative for it.
            '';
          };
          public = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = ''
              Parent zone for the public hub endpoint (ACME, WG hub
              external address). Per-service public domains live as
              individual zones in host.dnsAuthority.
            '';
          };
        };
      };
      default = {};
    };

    ipv6UlaPrefix = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "IPv6 ULA prefix (e.g. fd9a:e830:4b1e).";
    };

    iscsi = lib.mkOption {
      type = lib.types.submodule {
        options = {
          baseIqn = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = ''
              IQN prefix used when projecting lun entities to SCST targets
              and open-iscsi clients. Full IQN is
              "''${baseIqn}:''${producer}:''${lunName}".
            '';
          };
        };
      };
      default = {};
    };

    openbao = lib.mkOption {
      type = lib.types.submodule {
        options = {
          serverHost = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = ''
              Host entity name that runs the fleet OpenBao listener.
              Projections derive the OpenBao endpoint from this host's
              address on `serverNetwork` plus `port`.
            '';
          };
          serverNetwork = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = ''
              Network entity name whose `serverHost` address clients
              should reach OpenBao on. Read as
              `host.addresses.<serverNetwork>.ipv4`.
            '';
          };
          port = lib.mkOption {
            type = lib.types.int;
            default = 8200;
            description = "TCP port for the OpenBao listener.";
          };
          scheme = lib.mkOption {
            type = lib.types.enum [ "http" "https" ];
            default = "https";
            description = "URL scheme for the OpenBao listener.";
          };
        };
      };
      default = {};
    };
  };
}
