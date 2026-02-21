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
    collector = {
      enable = lib.mkEnableOption "Prometheus collector (scrapes local targets, remote-writes to server)";
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
      remoteWriteUrl = lib.mkOption {
        type = lib.types.str;
        description = "Prometheus remote_write endpoint URL.";
      };
    };
  };
  config = {
    cfg,
    lib,
    pkgs,
    ...
  }: let
    mkSnmpExporter = {
      enable = true;
      configurationPath = "${pkgs.prometheus-snmp-exporter.src}/snmp.yml";
      enableConfigCheck = false;
    };

    mkSnmpScrape = snmpTargets: {
      job_name = "snmp";
      metrics_path = "/snmp";
      params = {
        module = ["if_mib"];
        auth = ["public_v2"];
      };
      static_configs = [{targets = snmpTargets;}];
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
          replacement = "127.0.0.1:9116";
        }
      ];
    };
  in
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
          extraFlags = ["--web.enable-remote-write-receiver"];
          exporters.snmp = lib.mkIf (cfg.server.snmpTargets != []) mkSnmpExporter;
          scrapeConfigs =
            [
              {
                job_name = "node";
                static_configs = [
                  {targets = cfg.server.scrapeTargets ++ ["localhost:9100"];}
                ];
              }
            ]
            ++ lib.optional (cfg.server.snmpTargets != [])
            (mkSnmpScrape cfg.server.snmpTargets);
        };
      })
      (lib.mkIf cfg.collector.enable {
        services.prometheus = {
          enable = true;
          exporters.snmp = lib.mkIf (cfg.collector.snmpTargets != []) mkSnmpExporter;
          remoteWrite = [
            {url = cfg.collector.remoteWriteUrl;}
          ];
          scrapeConfigs =
            [
              {
                job_name = "node";
                static_configs = [
                  {targets = cfg.collector.scrapeTargets ++ ["localhost:9100"];}
                ];
              }
            ]
            ++ lib.optional (cfg.collector.snmpTargets != [])
            (mkSnmpScrape cfg.collector.snmpTargets);
        };
      })
    ];
}
