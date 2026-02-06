{
  path = ["psyclyx" "nixos" "services" "nsd"];
  description = "NSD authoritative DNS server";
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
        };
      });
      default = {};
      description = "Zone definitions.";
    };
  };

  config = {cfg, ...}: {
    services.nsd = {
      enable = true;
      interfaces = cfg.interfaces;
      port = cfg.port;
      zones = cfg.zones;
    };
  };
}
