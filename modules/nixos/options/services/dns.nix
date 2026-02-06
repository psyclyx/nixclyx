{
  path = ["psyclyx" "nixos" "services" "dns"];
  description = "DNS (authoritative + resolver)";
  options = {lib, ...}: {
    authoritative = {
      interfaces = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["127.0.0.1" "::1"];
        description = "Interfaces for authoritative DNS (NSD).";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 5353;
        description = "Port for authoritative DNS.";
      };
      zones = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            peerRecords = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Auto-generate A/AAAA records from pki.json peers.";
            };
            data = lib.mkOption {
              type = lib.types.nullOr lib.types.lines;
              default = null;
              description = "Raw zone data. Mutually exclusive with peerRecords.";
            };
            extraRecords = lib.mkOption {
              type = lib.types.lines;
              default = "";
              description = "Additional records (appended to auto-generated or data).";
            };
            ttl = lib.mkOption {
              type = lib.types.int;
              default = 300;
              description = "Default TTL for the zone.";
            };
            ns = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Nameserver hostname. Defaults to ns.<zone>.";
            };
            admin = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Admin email (SOA). Defaults to admin.<zone>.";
            };
          };
        });
        default = {};
        description = "Authoritative zones.";
      };
    };

    resolver = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable resolver (Unbound).";
      };
      interfaces = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Interfaces for resolver. Use interface names (wg0) or IPs.";
      };
      upstream = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["1.1.1.1@853#cloudflare-dns.com" "1.0.0.1@853#cloudflare-dns.com"];
        description = "Upstream DNS servers.";
      };
      upstreamTls = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Use TLS for upstream queries.";
      };
      extraStubZones = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional zones to stub to authoritative (beyond auto-detected).";
      };
      accessControl = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional access-control entries. VPN subnets added automatically.";
      };
    };
  };

  config = {cfg, config, lib, nixclyx, ...}: let
    net = nixclyx.network;
    hub = net.peers.${net.rootHub};
    hasZones = cfg.authoritative.zones != {};

    # Resolve interface names to IPs where needed
    resolveInterfaces = ifaces: let
      # For resolver, we need to also include hub IPs if wg0 is specified
      expandWg = iface:
        if iface == "wg0" then [hub.ip4 hub.ip6]
        else [iface];
    in lib.flatten (map expandWg ifaces);

    # Generate zone data
    mkZoneData = name: zoneCfg: let
      ns = if zoneCfg.ns != null then zoneCfg.ns else "ns.${name}";
      admin = if zoneCfg.admin != null then zoneCfg.admin else "admin.${name}";

      peerRecords = lib.optionalString zoneCfg.peerRecords (
        lib.concatStringsSep "\n" (lib.mapAttrsToList (peerName: peer: ''
          ${peerName}    IN A     ${peer.ip4}
          ${peerName}    IN AAAA  ${peer.ip6}
        '') net.peers)
      );

      baseData = if zoneCfg.data != null then zoneCfg.data else ''
        $ORIGIN ${name}.
        $TTL ${toString zoneCfg.ttl}
        @    IN SOA  ${ns}. ${admin}. (
                     1 3600 900 604800 300 )
        @    IN NS   ${ns}.
        ns   IN A    ${hub.ip4}
        ns   IN AAAA ${hub.ip6}
        ${peerRecords}
      '';
    in baseData + zoneCfg.extraRecords;

    # Build NSD zones
    nsdZones = lib.mapAttrs (name: zoneCfg: {
      data = mkZoneData name zoneCfg;
    }) cfg.authoritative.zones;

    # Stub zones for unbound = all authoritative zones + extras
    stubZoneNames = (lib.attrNames cfg.authoritative.zones) ++ cfg.resolver.extraStubZones;
    stubZones = map (name: {
      inherit name;
      stub-addr = "127.0.0.1@${toString cfg.authoritative.port}";
    }) stubZoneNames;

    # Access control for unbound
    subnetAcl = map (s: "${s} allow") (net.allSubnets4 ++ net.allSubnets6);

    resolverInterfaces = resolveInterfaces cfg.resolver.interfaces;

  in lib.mkMerge [
    # Authoritative DNS (NSD)
    (lib.mkIf hasZones {
      services.nsd = {
        enable = true;
        interfaces = cfg.authoritative.interfaces;
        port = cfg.authoritative.port;
        zones = nsdZones;
      };
    })

    # Resolver (Unbound)
    (lib.mkIf cfg.resolver.enable {
      services.unbound = {
        enable = true;
        settings = {
          server = {
            interface = ["127.0.0.1" "::1"] ++ resolverInterfaces;
            access-control = [
              "127.0.0.0/8 allow"
              "::1/128 allow"
            ] ++ subnetAcl ++ cfg.resolver.accessControl;
            do-not-query-localhost = false;
          };
          stub-zone = stubZones;
          forward-zone = [{
            name = ".";
            forward-tls-upstream = cfg.resolver.upstreamTls;
            forward-addr = cfg.resolver.upstream;
          }];
        };
      };

      # Disable systemd-resolved stub listener
      services.resolved.settings.Resolve.DNSStubListener = false;
    })
  ];
}
