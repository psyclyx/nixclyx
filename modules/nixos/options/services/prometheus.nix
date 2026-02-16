{
  path = ["psyclyx" "nixos" "services" "prometheus"];
  description = "Prometheus monitoring";
  options = {lib, ...}: {
    server = {
      enable = lib.mkEnableOption "Prometheus server";
      scrapeTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "List of host:port strings for node exporter scrape targets.";
      };
    };
  };
  config = {cfg, lib, ...}:
    lib.mkMerge [
      {
        services.prometheus.exporters.node = {
          enable = true;
          enabledCollectors = ["systemd"];
          openFirewall = true;
        };
      }
      (lib.mkIf cfg.server.enable {
        services.prometheus = {
          enable = true;
          scrapeConfigs = [
            {
              job_name = "node";
              static_configs = [
                {
                  targets = cfg.server.scrapeTargets ++ ["localhost:9100"];
                }
              ];
            }
          ];
        };
      })
    ];
}
