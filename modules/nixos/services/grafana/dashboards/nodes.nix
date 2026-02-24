{ mkDashboard, timeseries, bargauge, q, stdVars, thresholds, ... }:

mkDashboard {
  uid = "psyclyx-nodes";
  title = "Nodes";
  tags = [ "nodes" ];
  vars = stdVars "node_uname_info";

  panels = [
    (timeseries {
      title = "CPU by Mode"; unit = "percent"; min = 0;
      fillOpacity = 80;
      extraOptions = { legend.displayMode = "list"; };
      targets = [
        (q { expr = ''avg by(mode) (rate(node_cpu_seconds_total{instance=~"$instance",mode=~"user|system|iowait|steal"}[$__rate_interval])) * 100''; legendFormat = "{{mode}}"; })
      ];
    })

    (timeseries {
      title = "Load Average";
      targets = [
        (q { expr = ''node_load1{instance=~"$instance"}''; legendFormat = "{{instance}} 1m"; })
        (q { expr = ''node_load5{instance=~"$instance"}''; legendFormat = "{{instance}} 5m"; })
        (q { expr = ''node_load15{instance=~"$instance"}''; legendFormat = "{{instance}} 15m"; })
      ];
    })

    (timeseries {
      title = "Memory Usage"; unit = "bytes";
      targets = [
        (q { expr = ''node_memory_MemTotal_bytes{instance=~"$instance"} - node_memory_MemAvailable_bytes{instance=~"$instance"}''; legendFormat = "{{instance}} used"; })
        (q { expr = ''node_memory_Cached_bytes{instance=~"$instance"}''; legendFormat = "{{instance}} cached"; })
        (q { expr = ''node_memory_Buffers_bytes{instance=~"$instance"}''; legendFormat = "{{instance}} buffers"; })
      ];
    })

    (bargauge {
      title = "Filesystem Usage";
      targets = [
        (q { expr = ''100 - (node_filesystem_avail_bytes{instance=~"$instance",fstype!~"tmpfs|overlay|squashfs",mountpoint!~"/boot.*"} / node_filesystem_size_bytes{instance=~"$instance",fstype!~"tmpfs|overlay|squashfs",mountpoint!~"/boot.*"} * 100)''; legendFormat = "{{instance}} {{mountpoint}}"; })
      ];
    })

    (timeseries {
      title = "Network RX"; unit = "Bps";
      targets = [
        (q { expr = ''rate(node_network_receive_bytes_total{instance=~"$instance",device!~"lo|veth.*|br-.*|docker.*"}[$__rate_interval])''; legendFormat = "{{instance}} {{device}}"; })
      ];
    })

    (timeseries {
      title = "Network TX"; unit = "Bps";
      targets = [
        (q { expr = ''rate(node_network_transmit_bytes_total{instance=~"$instance",device!~"lo|veth.*|br-.*|docker.*"}[$__rate_interval])''; legendFormat = "{{instance}} {{device}}"; })
      ];
    })

    (timeseries {
      title = "PSI Pressure"; unit = "percentunit";
      targets = [
        (q { expr = ''rate(node_pressure_cpu_waiting_seconds_total{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} cpu"; })
        (q { expr = ''rate(node_pressure_memory_waiting_seconds_total{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} memory"; })
        (q { expr = ''rate(node_pressure_io_waiting_seconds_total{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} io"; })
      ];
    })

    (timeseries {
      title = "Failed Systemd Units";
      targets = [
        (q { expr = ''count by(instance) (node_systemd_unit_state{instance=~"$instance",state="failed"} == 1)''; })
      ];
    })

    (timeseries {
      title = "Conntrack Usage"; unit = "percent"; min = 0; max = 100;
      thresholds = thresholds.percentage;
      targets = [
        (q { expr = ''node_nf_conntrack_entries{instance=~"$instance"} / node_nf_conntrack_entries_limit{instance=~"$instance"} * 100''; })
      ];
    })

    (timeseries {
      title = "File Descriptor Usage"; unit = "percent"; min = 0; max = 100;
      thresholds = thresholds.percentage;
      targets = [
        (q { expr = ''node_filefd_allocated{instance=~"$instance"} / node_filefd_maximum{instance=~"$instance"} * 100''; })
      ];
    })
  ];
}
