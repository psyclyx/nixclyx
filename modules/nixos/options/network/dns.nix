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
      ns = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "IP address for auto-generated ns1/ns2 glue records. Required when zones use auto-generated SOA.";
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
        description = "Interfaces for resolver (IPs).";
      };
      extraStubZones = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional zones to stub (beyond authoritative zones).";
      };
      accessControl = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "ACL entries for the resolver (e.g., '10.0.0.0/24 allow').";
      };
      localZones = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            type = lib.mkOption {
              type = lib.types.enum ["static" "transparent" "typetransparent" "redirect"];
              default = "static";
              description = "Unbound local-zone type. 'static' serves only local-data (NXDOMAIN otherwise). 'transparent' falls through to normal resolution on miss.";
            };
            records = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              description = "DNS records (e.g., 'host.example.com. IN A 10.0.0.1').";
            };
          };
        });
        default = {};
        description = "Zones served locally by the resolver via unbound local-data.";
      };
    };
  };

  config = {
    cfg,
    lib,
    ...
  }: let
    hasZones = cfg.authoritative.zones != {};

    # Generate zone data from config
    mkZoneData = name: zoneCfg: let
      ns1 = "ns1.${name}";
      ns2 = "ns2.${name}";
      admin =
        if zoneCfg.admin != null
        then zoneCfg.admin
        else "admin.${name}";

      nsGlue = lib.optionalString (cfg.authoritative.ns != null) ''
        ns1  IN A    ${cfg.authoritative.ns}
        ns2  IN A    ${cfg.authoritative.ns}
      '';

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
          ${nsGlue}
        '';
    in
      baseData + zoneCfg.extraRecords;

    # Stub zone names for resolver
    stubZoneNames = (lib.attrNames cfg.authoritative.zones) ++ cfg.resolver.extraStubZones;
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
          # Auto-add localhost when resolver needs to stub to NSD
          interfaces =
            cfg.authoritative.interfaces
            ++ lib.optionals cfg.resolver.enable ["127.0.0.1" "::1"];
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
      (lib.mkIf cfg.resolver.enable (let
        localZoneCfg = cfg.resolver.localZones;
      in {
        psyclyx.nixos.services.unbound = {
          enable = true;
          interfaces = cfg.resolver.interfaces;
          accessControl = cfg.resolver.accessControl;
          stubZones =
            map (name: {
              inherit name;
              stub-addr = "127.0.0.1@${toString cfg.authoritative.port}";
            })
            stubZoneNames;
          localZones =
            lib.mapAttrs (_: z: z.type) localZoneCfg;
          localData =
            lib.concatLists (lib.mapAttrsToList (_: z: z.records) localZoneCfg);
        };
      }))
    ];
}
