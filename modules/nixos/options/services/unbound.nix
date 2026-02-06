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

  config = {cfg, lib, ...}: {
    services.unbound = {
      enable = true;
      settings = {
        server = {
          interface = ["127.0.0.1" "::1"] ++ cfg.interfaces;
          access-control = [
            "127.0.0.0/8 allow"
            "::1/128 allow"
          ] ++ cfg.accessControl;
          do-not-query-localhost = false;
        };
        stub-zone = cfg.stubZones;
        forward-zone = [{
          name = ".";
          forward-tls-upstream = cfg.forward.tls;
          forward-addr = cfg.forward.upstream;
        }];
      };
    };

    # Disable systemd-resolved stub listener and mDNS when running our own resolver
    services.resolved.settings.Resolve = {
      DNSStubListener = false;
      MulticastDNS = false;
    };
  };
}
