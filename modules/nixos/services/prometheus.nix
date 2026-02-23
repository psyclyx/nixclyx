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
      extraScrapeConfigs = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [];
        description = "Additional Prometheus scrape_config job objects.";
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
      extraScrapeConfigs = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [];
        description = "Additional Prometheus scrape_config job objects.";
      };
      remoteWriteUrl = lib.mkOption {
        type = lib.types.str;
        description = "Prometheus remote_write endpoint URL.";
      };
    };
  };
  config = {
    cfg,
    config,
    lib,
    pkgs,
    ...
  }: let
    topo = config.psyclyx.topology;
    selfTarget = "${config.psyclyx.nixos.host}.${topo.domains.internal}:9100";
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
        services.prometheus.exporters.smartctl = {
          enable = true;
          openFirewall = true;
        };
        systemd.services.prometheus-smartctl-exporter.serviceConfig = {
          DevicePolicy = lib.mkForce "auto";
          CapabilityBoundingSet = lib.mkForce ["CAP_SYS_RAWIO" "CAP_DAC_OVERRIDE" "CAP_SYS_ADMIN"];
          AmbientCapabilities = lib.mkForce ["CAP_SYS_RAWIO" "CAP_DAC_OVERRIDE" "CAP_SYS_ADMIN"];
        };
      }
      (lib.mkIf cfg.server.enable {
        services.prometheus = {
          enable = true;
          globalConfig.scrape_interval = "10s";
          extraFlags = ["--web.enable-remote-write-receiver"];
          exporters.snmp = lib.mkIf (cfg.server.snmpTargets != []) mkSnmpExporter;
          scrapeConfigs =
            [
              {
                job_name = "node";
                static_configs = [
                  {targets = cfg.server.scrapeTargets ++ [selfTarget];}
                ];
              }
            ]
            ++ lib.optional (cfg.server.snmpTargets != [])
            (mkSnmpScrape cfg.server.snmpTargets)
            ++ cfg.server.extraScrapeConfigs;
        };
      })
      (lib.mkIf cfg.collector.enable {
        services.prometheus = {
          enable = true;
          globalConfig.scrape_interval = "10s";
          exporters.snmp = lib.mkIf (cfg.collector.snmpTargets != []) mkSnmpExporter;
          remoteWrite = [
            {url = cfg.collector.remoteWriteUrl;}
          ];
          scrapeConfigs =
            [
              {
                job_name = "node";
                # Don't add localhost:9100 here — the collector is already in its
                # own scrapeTargets via FQDN (from spokeVpnTargets).  Adding
                # localhost:9100 would double-scrape the local node_exporter and,
                # worse, the "localhost:9100" instance label collides with the
                # server's own localhost:9100 when remote-written.
                static_configs = [
                  {targets = cfg.collector.scrapeTargets;}
                ];
              }
            ]
            ++ lib.optional (cfg.collector.snmpTargets != [])
            (mkSnmpScrape cfg.collector.snmpTargets)
            ++ cfg.collector.extraScrapeConfigs;
        };
      })
    ];
}
