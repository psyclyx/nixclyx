{ mkDashboard, timeseries, table, stat, bargauge, q, qt, dsFixed, thresholds
, seriesToColumns, organize, colorBgOverride, thresholdOverride, unitOverride, mappingOverride
, ... }:

let
  ds = dsFixed "psyclyx-prometheus";
  upDownMapping = [{ options = { "0" = { color = "red"; text = "Down"; }; "1" = { color = "green"; text = "Up"; }; }; type = "value"; }];
in
mkDashboard {
  uid = "psyclyx-overview";
  title = "Overview";
  tags = [ "overview" ];
  time = { from = "now-1h"; to = "now"; };

  panels = [
    (table {
      title = "Node Status";
      datasource = ds;
      targets = [
        (qt { expr = ''up{job="node"}''; })
        (qt { expr = "time() - node_boot_time_seconds"; })
        (qt { expr = ''100 - (avg by(instance) (sum by(instance, cpu) (rate(node_cpu_seconds_total{mode=~"idle|iowait"}[5m]))) * 100)''; })
        (qt { expr = "(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100"; })
        (qt { expr = ''100 - (node_filesystem_avail_bytes{mountpoint="/",fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes{mountpoint="/",fstype!~"tmpfs|overlay"} * 100)''; })
        (qt { expr = ''count by(instance) (node_systemd_unit_state{state="failed"} == 1)''; })
      ];
      h = 5;
      transformations = [
        (seriesToColumns "instance")
        (organize {
          excludeByName = {
            "Time 1" = true; "Time 2" = true; "Time 3" = true;
            "Time 4" = true; "Time 5" = true; "Time 6" = true;
            "__name__ 1" = true; "__name__ 2" = true; "__name__ 3" = true;
            "__name__ 4" = true; "__name__ 5" = true;
            "job 1" = true; "job 2" = true; "job 3" = true;
            "job 4" = true; "job 5" = true; "job 6" = true;
            "fstype" = true; "mountpoint" = true;
          };
          indexByName = {
            "instance" = 0; "Value #A" = 1; "Value #B" = 2;
            "Value #C" = 3; "Value #D" = 4; "Value #E" = 5; "Value #F" = 6;
          };
          renameByName = {
            "instance" = "Host"; "Value #A" = "Status"; "Value #B" = "Uptime";
            "Value #C" = "CPU %"; "Value #D" = "Memory %";
            "Value #E" = "Root Disk %"; "Value #F" = "Failed Units";
          };
        })
      ];
      overrides = [
        ((mappingOverride "Status" upDownMapping) // {
          properties = (mappingOverride "Status" upDownMapping).properties
            ++ (colorBgOverride "Status").properties;
        })
        (unitOverride "Uptime" "dtdurations")
        (thresholdOverride "CPU %" thresholds.percentage)
        (thresholdOverride "Memory %" thresholds.percentage)
        (thresholdOverride "Root Disk %" thresholds.percentage)
        (thresholdOverride "Failed Units" (thresholds.mk [
          (thresholds.step "green" null)
          (thresholds.step "red" 1)
        ]))
      ];
      extraOptions = { sortBy = [{ desc = false; displayName = "Host"; }]; };
    })

    (stat {
      title = "Nodes Up";
      datasource = ds;
      thresholds = thresholds.upDown;
      targets = [
        (q { expr = ''count(up{job="node"} == 1)''; legendFormat = ""; })
      ];
    })

    (stat {
      title = "PostgreSQL";
      datasource = ds;
      thresholds = thresholds.upDown;
      targets = [
        (q { expr = ''count(pg_up == 1)''; legendFormat = ""; })
      ];
    })

    (stat {
      title = "Redis";
      datasource = ds;
      thresholds = thresholds.upDown;
      targets = [
        (q { expr = ''count(redis_up == 1)''; legendFormat = ""; })
      ];
    })

    (stat {
      title = "SeaweedFS";
      datasource = ds;
      thresholds = thresholds.upDown;
      targets = [
        (q { expr = ''count(SeaweedFS_master_is_leader == 1)''; legendFormat = ""; })
      ];
    })

    (stat {
      title = "SMART OK";
      datasource = ds;
      thresholds = thresholds.upDown;
      targets = [
        (q { expr = ''count(smartctl_device_smartctl_exit_status == 0)''; legendFormat = ""; })
      ];
    })

    (stat {
      title = "Failed Units";
      datasource = ds;
      thresholds = thresholds.mk [
        (thresholds.step "green" null)
        (thresholds.step "red" 1)
      ];
      targets = [
        (q { expr = ''sum(node_systemd_unit_state{state="failed"} == 1) or vector(0)''; legendFormat = ""; })
      ];
    })

    (timeseries {
      title = "CPU Usage (Fleet)"; unit = "percent"; min = 0; max = 100;
      datasource = ds;
      targets = [
        (q { expr = ''100 - (avg by(instance) (sum by(instance, cpu) (rate(node_cpu_seconds_total{mode=~"idle|iowait"}[$__rate_interval]))) * 100)''; })
      ];
    })

    (timeseries {
      title = "Memory Usage (Fleet)"; unit = "percent"; min = 0; max = 100;
      datasource = ds; h = 6;
      targets = [
        (q { expr = "(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100"; })
      ];
    })
  ];
}
