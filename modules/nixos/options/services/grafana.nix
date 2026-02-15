{
  path = ["psyclyx" "nixos" "services" "grafana"];
  description = "Visualization and dashboarding tool";
  options = {lib, ...}: {
    listen = {
      address = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Address the http server binds to.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 2134;
        description = "Port the http server binds to.";
      };
    };
    domain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = "Domain the server runs on.";
    };
  };

  config = {
    cfg,
    lib,
    ...
  }: {
    services.grafana = {
      enable = true;
      settings = {
        server = {
          http_addr = cfg.listen.address;
          http_port = cfg.listen.port;
          enable_gzip = true;
          domain = lib.mkIf (cfg.domain != null) cfg.domain;
          enforce_domain = lib.mkIf (cfg.domain != null) true;
        };
        analytics.reporting_enabled = false;
      };
    };
  };
}
