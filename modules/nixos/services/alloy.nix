{
  path = ["psyclyx" "nixos" "services" "alloy"];
  description = "Grafana Alloy log shipping agent (replaces promtail)";
  options = {lib, ...}: {
    lokiUrl = lib.mkOption {
      type = lib.types.str;
      description = "Base URL of the Loki instance (e.g. http://10.157.0.1:3100).";
    };
  };
  config = {cfg, ...}: {
    services.alloy.enable = true;
    environment.etc."alloy/config.alloy".text = ''
      loki.relabel "journal" {
        forward_to = []
        rule {
          source_labels = ["__journal__hostname"]
          target_label  = "host"
        }
        rule {
          source_labels = ["__journal__systemd_unit"]
          target_label  = "unit"
        }
      }

      loki.source.journal "read" {
        forward_to    = [loki.write.endpoint.receiver]
        relabel_rules = loki.relabel.journal.rules
      }

      loki.write "endpoint" {
        endpoint {
          url = "${cfg.lokiUrl}/loki/api/v1/push"
        }
      }
    '';
  };
}
