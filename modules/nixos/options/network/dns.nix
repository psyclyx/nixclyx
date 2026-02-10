{
  path = ["psyclyx" "nixos" "network" "dns"];
  description = "Network DNS configuration";
  # Auto-enable when any DNS config is present
  gate = {cfg, ...}: cfg.client.enable || cfg.authoritative.zones != {} || cfg.resolver.enable;
  options = {lib, ...}: {
    client = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable client DNS (avahi + systemd-resolved).";
      };
    };

    authoritative = {
      zones = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            peerRecords = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Auto-generate A/AAAA records from network.json peers.";
            };
            data = lib.mkOption {
              type = lib.types.nullOr lib.types.lines;
              default = null;
              description = "Raw zone data. If null, auto-generates SOA/NS.";
            };
            extraRecords = lib.mkOption {
              type = lib.types.lines;
              default = "";
              description = "Additional records appended to zone.";
            };
            ttl = lib.mkOption {
              type = lib.types.int;
              default = 300;
              description = "Default TTL.";
            };
            admin = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Admin email (SOA). Defaults to admin.<zone>.";
            };
          };
        });
        default = {};
        description = "Authoritative zones to serve.";
      };
      interfaces = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["127.0.0.1" "::1"];
        description = "Interfaces for authoritative DNS.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 5353;
        description = "Port for authoritative DNS.";
      };
    };

    resolver = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable DNS resolver.";
      };
      interfaces = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Interfaces for resolver. Use interface names (wg0) or IPs.";
      };
      extraStubZones = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional zones to stub (beyond authoritative zones).";
      };
    };
  };

  config = {
    cfg,
    config,
    lib,
    nixclyx,
    ...
  }: let
    net = nixclyx.network;
    hub = net.peers.${net.rootHub};
    hasZones = cfg.authoritative.zones != {};

    # Resolve interface names to IPs
    resolveInterfaces = ifaces: let
      expandWg = iface:
        if iface == "wg0"
        then [hub.ip4 hub.ip6]
        else [iface];
    in
      lib.flatten (map expandWg ifaces);

    # Generate zone data from config
    mkZoneData = name: zoneCfg: let
      ns1 = "ns1.${name}";
      ns2 = "ns2.${name}";
      admin =
        if zoneCfg.admin != null
        then zoneCfg.admin
        else "admin.${name}";

      peerRecords = lib.optionalString zoneCfg.peerRecords (
        lib.concatStringsSep "\n" (lib.mapAttrsToList (peerName: peer: ''
            ${peerName}    IN A     ${peer.ip4}
            ${peerName}    IN AAAA  ${peer.ip6}
          '')
          net.peers)
      );

      baseData =
        if zoneCfg.data != null
        then zoneCfg.data
        else ''
          $ORIGIN ${name}.
          $TTL ${toString zoneCfg.ttl}
          @    IN SOA  ${ns1}. ${admin}. (
                       1 3600 900 604800 300 )
          @    IN NS   ${ns1}.
          @    IN NS   ${ns2}.
          ns1  IN A    ${hub.endpoint}
          ns2  IN A    ${hub.endpoint}
          ${peerRecords}
        '';
    in
      baseData + zoneCfg.extraRecords;

    # Stub zone names for resolver
    stubZoneNames = (lib.attrNames cfg.authoritative.zones) ++ cfg.resolver.extraStubZones;

    # VPN subnet ACLs
    subnetAcl = map (s: "${s} allow") (net.allSubnets4 ++ net.allSubnets6);
  in
    lib.mkMerge [
      # Client mode: avahi + resolved
      (lib.mkIf cfg.client.enable {
        psyclyx.nixos.services = {
          avahi.enable = true;
          resolved.enable = true;
        };
      })

      # Authoritative DNS via NSD (auto-enabled by gate when zones != {})
      (lib.mkIf hasZones {
        psyclyx.nixos.services.nsd = {
          interfaces = cfg.authoritative.interfaces;
          port = cfg.authoritative.port;
          zones =
            lib.mapAttrs (name: zoneCfg: {
              data = mkZoneData name zoneCfg;
            })
            cfg.authoritative.zones;
        };
        # Disable avahi when NSD is using port 5353 (mDNS port conflict)
        services.avahi.enable = lib.mkIf (cfg.authoritative.port == 5353) (lib.mkForce false);
      })

      # Resolver via Unbound
      (lib.mkIf cfg.resolver.enable {
        psyclyx.nixos.services.unbound = {
          enable = true;
          interfaces = resolveInterfaces cfg.resolver.interfaces;
          accessControl = subnetAcl;
          stubZones =
            map (name: {
              inherit name;
              stub-addr = "127.0.0.1@${toString cfg.authoritative.port}";
            })
            stubZoneNames;
        };
      })
    ];
}
