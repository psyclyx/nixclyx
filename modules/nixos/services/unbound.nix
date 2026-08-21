{
  path = ["psyclyx" "nixos" "services" "unbound"];
  description = "Unbound DNS resolver";
  options = {lib, ...}: {
    interfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional interfaces to listen on (127.0.0.1 and ::1 always included).";
    };
    accessControl = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Access control entries (e.g., '10.0.0.0/8 allow').";
    };
    stubZones = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Zone name.";
          };
          stub-addr = lib.mkOption {
            type = lib.types.str;
            description = "Stub address (e.g., '127.0.0.1@5353').";
          };
        };
      });
      default = [];
      description = "Zones to stub to a local authoritative server.";
    };
    localZones = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Local zone declarations mapping zone name to type (e.g., { \"example.com\" = \"static\"; }).";
    };
    localData = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Local data entries without quoting (e.g., 'host.example.com. IN A 10.0.0.1').";
    };
    forwardZones = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Zone name.";
          };
          forward-addr = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Forward addresses for this zone.";
          };
        };
      });
      default = [];
      description = "Additional forward zones (beyond the default catch-all).";
    };
    forward = {
      upstream = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["1.1.1.1@853#cloudflare-dns.com" "1.0.0.1@853#cloudflare-dns.com"];
        description = "Upstream DNS servers.";
      };
      tls = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Use TLS for upstream queries.";
      };
    };
  };

  config = {
    cfg,
    lib,
    ...
  }: {
    services.unbound = {
      enable = true;
      # Local unix control socket so `unbound-control stats` works (cache
      # hit/miss, memory) — enables remote-control on this socket only.
      localControlSocketPath = "/run/unbound/unbound.ctl";
      settings = {
        server =
          {
            interface = ["127.0.0.1" "::1"] ++ cfg.interfaces;
            access-control =
              [
                "127.0.0.0/8 allow"
                "::1/128 allow"
              ]
              ++ cfg.accessControl;
            do-not-query-localhost = false;

            # Threading: inter-VLAN routing is hardware-offloaded onto the
            # switch (mdf-agg01); this mini-PC only does NAT/DNS/DHCP, so its
            # cores are free for the resolver. Use all four, with cache slabs
            # a power-of-two >= num-threads to cut lock contention.
            num-threads = 4;
            so-reuseport = true;
            msg-cache-slabs = 4;
            rrset-cache-slabs = 4;
            infra-cache-slabs = 4;
            key-cache-slabs = 4;

            # Caches: trivial against this host's RAM, far better hit rate
            # than unbound's 4 MB defaults. rrset ~2x msg is the usual ratio.
            msg-cache-size = "64m";
            rrset-cache-size = "128m";

            # Refresh popular cache entries before they expire (incl. DNSKEY).
            prefetch = true;
            prefetch-key = true;
            # Serve stale records while fetching fresh ones in the background;
            # answer from stale within 1.8s if the refresh is slow (RFC 8767).
            serve-expired = true;
            serve-expired-ttl = 86400;
            serve-expired-client-timeout = 1800;
          }
          // lib.optionalAttrs (cfg.localZones != {}) {
            local-zone = lib.mapAttrsToList (name: type: ''"${name}." ${type}'') cfg.localZones;
          }
          // lib.optionalAttrs (cfg.localData != []) {
            local-data = map (d: ''"${d}"'') cfg.localData;
          };
        stub-zone = cfg.stubZones;
        forward-zone = cfg.forwardZones ++ [
          {
            name = ".";
            forward-tls-upstream = cfg.forward.tls;
            forward-addr = cfg.forward.upstream;
          }
        ];
      };
    };

    # Disable systemd-resolved stub listener and mDNS when running our own resolver
    services.resolved.settings.Resolve = {
      DNSStubListener = false;
      MulticastDNS = false;
    };
  };
}
