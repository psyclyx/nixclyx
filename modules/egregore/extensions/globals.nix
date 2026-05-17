# Global configuration — cross-cutting values used by type modules
# and projections. Not entities — context.
{ lib, ... }: {
  options = {
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
  };
}
