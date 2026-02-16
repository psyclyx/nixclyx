{
  path = ["psyclyx" "nixos" "services" "promtail"];
  description = "Promtail log shipping agent";
  options = {lib, ...}: {
    lokiUrl = lib.mkOption {
      type = lib.types.str;
      description = "URL of the Loki push endpoint (e.g. http://10.157.0.1:3100).";
    };
  };
  config = {cfg, ...}: {
    services.promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = 9080;
          grpc_listen_port = 0;
        };
        positions.filename = "/var/lib/promtail/positions.yaml";
        clients = [
          {
            url = "${cfg.lokiUrl}/loki/api/v1/push";
          }
        ];
        scrape_configs = [
          {
            job_name = "journal";
            journal = {
              max_age = "12h";
              labels.job = "systemd-journal";
            };
            relabel_configs = [
              {
                source_labels = ["__journal__hostname"];
                target_label = "host";
              }
              {
                source_labels = ["__journal__systemd_unit"];
                target_label = "unit";
              }
            ];
          }
        ];
      };
    };
  };
}
