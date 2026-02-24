{ mkDashboard, timeseries, bargauge, q, queryVar, promDatasourceVar, thresholds, ... }:

mkDashboard {
  uid = "psyclyx-storage";
  title = "Storage";
  tags = [ "storage" "disk" ];
  vars = [
    promDatasourceVar
    (queryVar { metric = "node_uname_info"; })
    (queryVar { name = "device"; metric = "node_disk_io_time_seconds_total"; label = "device"; })
  ];

  panels = [
    (bargauge {
      title = "Filesystem Usage"; w = 24;
      targets = [
        (q { expr = ''100 - (node_filesystem_avail_bytes{instance=~"$instance",fstype!~"tmpfs|overlay|squashfs",mountpoint!~"/boot.*"} / node_filesystem_size_bytes{instance=~"$instance",fstype!~"tmpfs|overlay|squashfs",mountpoint!~"/boot.*"} * 100)''; legendFormat = "{{instance}} {{mountpoint}}"; })
      ];
    })

    (timeseries {
      title = "Disk Read Throughput"; unit = "Bps";
      targets = [
        (q { expr = ''rate(node_disk_read_bytes_total{instance=~"$instance",device=~"$device"}[$__rate_interval])''; legendFormat = "{{instance}} {{device}}"; })
      ];
    })

    (timeseries {
      title = "Disk Write Throughput"; unit = "Bps";
      targets = [
        (q { expr = ''rate(node_disk_written_bytes_total{instance=~"$instance",device=~"$device"}[$__rate_interval])''; legendFormat = "{{instance}} {{device}}"; })
      ];
    })

    (timeseries {
      title = "Disk I/O Utilization"; unit = "percent"; min = 0; max = 100;
      targets = [
        (q { expr = ''rate(node_disk_io_time_seconds_total{instance=~"$instance",device=~"$device"}[$__rate_interval]) * 100''; legendFormat = "{{instance}} {{device}}"; })
      ];
    })

    (timeseries {
      title = "Disk Read Latency"; unit = "s";
      targets = [
        (q { expr = ''rate(node_disk_read_time_seconds_total{instance=~"$instance",device=~"$device"}[$__rate_interval]) / rate(node_disk_reads_completed_total{instance=~"$instance",device=~"$device"}[$__rate_interval])''; legendFormat = "{{instance}} {{device}}"; })
      ];
    })

    (timeseries {
      title = "Disk Write Latency"; unit = "s";
      targets = [
        (q { expr = ''rate(node_disk_write_time_seconds_total{instance=~"$instance",device=~"$device"}[$__rate_interval]) / rate(node_disk_writes_completed_total{instance=~"$instance",device=~"$device"}[$__rate_interval])''; legendFormat = "{{instance}} {{device}}"; })
      ];
    })

    (timeseries {
      title = "Disk I/O Weighted Time";
      targets = [
        (q { expr = ''rate(node_disk_io_time_weighted_seconds_total{instance=~"$instance",device=~"$device"}[$__rate_interval])''; legendFormat = "{{instance}} {{device}}"; })
      ];
    })
  ];
}
