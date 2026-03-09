{
  path = ["psyclyx" "nixos" "services" "knot"];
  description = "Knot authoritative DNS server";
  gate = {cfg, ...}: cfg.zones != {};
  options = {lib, ...}: {
    interfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["127.0.0.1" "::1"];
      description = "Interfaces to listen on.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 5353;
      description = "Port for authoritative DNS (5353 for local stub, 53 for public).";
    };
    zones = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          data = lib.mkOption {
            type = lib.types.lines;
            description = "Zone file data.";
          };
          ddns = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Allow RFC 2136 dynamic updates (authenticated by TSIG).";
          };
        };
      });
      default = {};
      description = "Zone definitions.";
    };
    tsigKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a file containing TSIG key config (Knot YAML format). Used for DDNS and ACME.";
    };
    tsigKeyName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Name of the TSIG key (must match the key defined in tsigKeyFile).";
    };
  };

  config = {
    cfg,
    lib,
    pkgs,
    ...
  }: let
    hasDdns = lib.any (z: z.ddns) (lib.attrValues cfg.zones);
    hasTsig = cfg.tsigKeyFile != null && cfg.tsigKeyName != null;

    zoneSettings = lib.mapAttrs (name: zoneCfg: {
      file = pkgs.writeText "${name}.zone" zoneCfg.data;
      zonefile-load = if zoneCfg.ddns then "difference" else "whole";
    } // lib.optionalAttrs zoneCfg.ddns {
      journal-content = "all";
      acl = ["acl-ddns"];
    }) cfg.zones;
  in {
    services.knot = {
      enable = true;
      keyFiles = lib.optional hasTsig cfg.tsigKeyFile;
      settings = {
        server = {
          listen = map (iface: "${iface}@${toString cfg.port}") cfg.interfaces;
        };
        acl = lib.optional (hasDdns && hasTsig) {
          id = "acl-ddns";
          key = cfg.tsigKeyName;
          action = "update";
        };
        zone = zoneSettings;
      };
    };

    # Open firewall for public DNS
    psyclyx.nixos.network.ports.dns = lib.mkIf (cfg.port == 53) {tcp = [53]; udp = [53];};
  };
}
