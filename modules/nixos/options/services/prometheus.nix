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
      snmpTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "List of SNMP device addresses to scrape via snmp_exporter.";
      };
    };
  };
  config = {
    cfg,
    lib,
    ...
  }:
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
          exporters.snmp = lib.mkIf (cfg.server.snmpTargets != []) {
            enable = true;
          };
          scrapeConfigs =
            [
              {
                job_name = "node";
                static_configs = [
                  {
                    targets = cfg.server.scrapeTargets ++ ["localhost:9100"];
                  }
                ];
              }
            ]
            ++ lib.optional (cfg.server.snmpTargets != []) {
              job_name = "snmp";
              metrics_path = "/snmp";
              params.module = ["if_mib"];
              static_configs = [
                {
                  targets = cfg.server.snmpTargets;
                }
              ];
              relabel_configs = [
                {
                  source_labels = ["__address__"];
                  target_label = "__param_target";
                }
                {
                  source_labels = ["__param_target"];
                  target_label = "instance";
                }
                {
                  target_label = "__address__";
                  replacement = "127.0.0.1:${toString 9116}";
                }
              ];
            };
        };
      })
    ];
}
