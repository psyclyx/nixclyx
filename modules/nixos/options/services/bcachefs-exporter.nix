{
  path = ["psyclyx" "nixos" "services" "bcachefs-exporter"];
  description = "Bcachefs sysfs metrics textfile exporter for Prometheus";
  gate = {config, ...}: config.psyclyx.nixos.filesystems.bcachefs.enable;
  config = {config, lib, pkgs, ...}: let
    textfileDir = "/var/lib/prometheus-node-exporter/textfile";
    script = pkgs.writeShellScript "bcachefs-exporter" ''
      set -euo pipefail
      final="${textfileDir}/bcachefs.prom"

      while true; do
        out="${textfileDir}/bcachefs.prom.$$"
        : > "$out"

        for uuidDir in /sys/fs/bcachefs/*/; do
          [ -d "$uuidDir/counters" ] || continue
          uuid="$(basename "$uuidDir")"
          for counter in "$uuidDir"/counters/*; do
            [ -f "$counter" ] || continue
            name="$(basename "$counter")"
            # Counter files are multi-line; extract the cumulative (since creation) value.
            # Skip counters with human-readable suffixes (e.g. 183M, 4.82G).
            value="$(${pkgs.gawk}/bin/awk '/since filesystem creation:/ { print $NF }' "$counter")"
            case "$value" in
              *[!0-9]*) continue ;;
            esac
            printf 'bcachefs_counter{uuid="%s",name="%s"} %s\n' "$uuid" "$name" "$value" >> "$out"
          done
        done

        mv "$out" "$final"
        sleep 10
      done
    '';
  in {
    services.prometheus.exporters.node = {
      enabledCollectors = ["textfile"];
      extraFlags = ["--collector.textfile.directory=${textfileDir}"];
    };

    systemd.tmpfiles.rules = [
      "d ${textfileDir} 0755 root root -"
    ];

    systemd.services.bcachefs-exporter = {
      description = "Export bcachefs sysfs counters as Prometheus textfile metrics";
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = script;
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
