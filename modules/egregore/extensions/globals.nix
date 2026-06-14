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

    zones = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options.label = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Human-readable description (links/diagrams).";
        };
      });
      default = {};
      description = ''
        Zone declarations. A zone groups networks that share
        forward-policy treatment. Networks join zones via
        `network.zone`; forward policy is keyed by zone in
        `globals.policy`. Zones live in globals (not the entity
        registry) to avoid name collisions with networks/hosts of
        the same conceptual name (e.g. `storage` is both a network
        and a zone).
      '';
    };

    policy = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf (lib.types.enum [
        "accept" "drop" "reject"
      ]));
      default = {};
      description = ''
        Symmetric forward-policy matrix keyed by zone. Read as
        `policy.<src-zone>.<dst-zone>` → action. Default for any
        unspecified pair is implicit drop (gateway projections only
        emit accept/reject rules; the chain's default policy is drop).

        Networks join zones via `network.zone`. Multiple networks in
        the same zone share identical policy — that's the whole point
        of the abstraction.

        Gateway projections (iyr nftables, mdf-agg01 ACL generator)
        read the slice relevant to each gateway and emit rules from
        this one source of truth.
      '';
    };

    kerberos = lib.mkOption {
      type = lib.types.submodule {
        options = {
          realm = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = ''
              Kerberos realm name. Empty disables the projection;
              non-empty enables it and propagates to all hosts'
              krb5.conf via derived/kerberos.nix.
            '';
          };
          primary = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              Host entity name running the primary KDC. The projection
              enables psyclyx.nixos.services.kerberos-kdc on this host
              with role = "primary".
            '';
          };
          secondaries = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = ''
              Host entity names running secondary KDCs (kprop
              replicas). The projection enables kerberos-kdc on these
              hosts with role = "secondary".
            '';
          };
          kdcNetwork = lib.mkOption {
            type = lib.types.str;
            default = "vpn";
            description = ''
              Network entity name whose addresses are advertised in
              krb5.conf's KDC list. vpn is the safe choice — all hosts
              with VPN connectivity can reach the KDCs symmetrically.
            '';
          };
          domainRealmMappings = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = {};
            description = ''
              DNS domain → realm mappings injected into clients'
              krb5.conf. Empty default; populate when you want
              automatic principal-realm inference based on hostname.
            '';
          };
          userPrincipals = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = ''
              Bare usernames to provision as human user principals
              (`<user>@<realm>`) in the KDC. Unlike host/nfs principals
              these aren't derived from any entity — a human accessing a
              krb5* NFS mount under their own uid needs a per-user
              principal (MIT krb5 maps the single-component principal
              `user@REALM` to the local account `user`). The KDC mints
              each with a random key and pushes its keytab to OpenBao
              like any other principal; the consuming host pulls that
              keytab and runs an auto-kinit (see the kerberos
              user-ticket module).
            '';
          };
        };
      };
      default = {};
      description = ''
        Fleet Kerberos config. Projected into KDC + client modules by
        derived/kerberos.nix. Disabled when realm = "".
      '';
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
