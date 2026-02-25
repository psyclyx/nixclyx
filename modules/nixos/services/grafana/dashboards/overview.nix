{ mkDashboard, timeseries, stat, q, dsFixed, thresholds, ... }:

let
  ds = dsFixed "psyclyx-prometheus";
in
mkDashboard {
  uid = "psyclyx-overview";
  title = "Overview";
  tags = [ "overview" ];
  time = { from = "now-1h"; to = "now"; };

  panels = [
    (stat {
      title = "Nodes Up"; w = 3;
      datasource = ds;
      thresholds = thresholds.upDown;
      targets = [
        (q { expr = ''count(up{job="node"} == 1)''; legendFormat = ""; })
      ];
    })

    (stat {
      title = "PostgreSQL"; w = 3;
      datasource = ds;
      thresholds = thresholds.upDown;
      targets = [
        (q { expr = ''count(pg_up == 1)''; legendFormat = ""; })
      ];
    })

    (stat {
      title = "Redis"; w = 3;
      datasource = ds;
      thresholds = thresholds.upDown;
      targets = [
        (q { expr = ''count(redis_up == 1)''; legendFormat = ""; })
      ];
    })

    (stat {
      title = "SeaweedFS"; w = 3;
      datasource = ds;
      thresholds = thresholds.upDown;
      targets = [
        (q { expr = ''count(SeaweedFS_master_is_leader == 1)''; legendFormat = ""; })
      ];
    })

    (stat {
      title = "SMART OK"; w = 3;
      datasource = ds;
      thresholds = thresholds.upDown;
      targets = [
        (q { expr = ''count(smartctl_device_smartctl_exit_status == 0)''; legendFormat = ""; })
      ];
    })

    (stat {
      title = "Failed Units"; w = 3;
      datasource = ds;
      thresholds = thresholds.mk [
        (thresholds.step "green" null)
        (thresholds.step "red" 1)
      ];
      targets = [
        (q { expr = ''sum(node_systemd_unit_state{state="failed"} == 1) or vector(0)''; legendFormat = ""; })
      ];
    })

    (stat {
      title = "OOM Kills"; w = 3;
      datasource = ds;
      thresholds = thresholds.mk [
        (thresholds.step "green" null)
        (thresholds.step "red" 1)
      ];
      targets = [
        (q { expr = ''sum(increase(node_vmstat_oom_kill[1h])) or vector(0)''; legendFormat = ""; })
      ];
    })

    (stat {
      title = "Swapping"; w = 3;
      datasource = ds;
      thresholds = thresholds.mk [
        (thresholds.step "green" null)
        (thresholds.step "red" 1)
      ];
      targets = [
        (q { expr = ''count(node_memory_SwapTotal_bytes - node_memory_SwapFree_bytes > 0) or vector(0)''; legendFormat = ""; })
      ];
    })

    (timeseries {
      title = "CPU Usage (Fleet)"; unit = "percent"; min = 0; max = 100;
      datasource = ds;
      targets = [
        (q { expr = ''avg by(instance) (sum by(instance, cpu) (rate(node_cpu_seconds_total{mode=~"user|nice|irq|softirq|steal"}[$__rate_interval]))) * 100''; })
      ];
    })

    (timeseries {
      title = "Memory Usage (Fleet)"; unit = "percent"; min = 0; max = 100;
      datasource = ds;
      targets = [
        (q { expr = "(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100"; })
      ];
    })

    (timeseries {
      title = "Network I/O (Fleet)"; unit = "Bps";
      datasource = ds;
      targets = [
        (q { expr = ''sum by(instance) (rate(node_network_receive_bytes_total{device!~"lo|veth.*|br-.*|docker.*"}[$__rate_interval]))''; legendFormat = "{{instance}} rx"; })
        (q { expr = ''sum by(instance) (rate(node_network_transmit_bytes_total{device!~"lo|veth.*|br-.*|docker.*"}[$__rate_interval]))''; legendFormat = "{{instance}} tx"; })
      ];
    })

    (timeseries {
      title = "Disk I/O (Fleet)"; unit = "Bps";
      datasource = ds;
      targets = [
        (q { expr = ''sum by(instance) (rate(node_disk_read_bytes_total{device!~"dm-.*|loop.*|sr.*"}[$__rate_interval]))''; legendFormat = "{{instance}} read"; })
        (q { expr = ''sum by(instance) (rate(node_disk_written_bytes_total{device!~"dm-.*|loop.*|sr.*"}[$__rate_interval]))''; legendFormat = "{{instance}} write"; })
      ];
    })
  ];
}
