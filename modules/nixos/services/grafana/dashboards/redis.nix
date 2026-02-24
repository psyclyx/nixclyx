{ mkDashboard, timeseries, q, stdVars, ... }:

mkDashboard {
  uid = "psyclyx-redis";
  title = "Redis";
  tags = [ "redis" "database" ];
  vars = stdVars "redis_up";

  panels = [
    (timeseries {
      title = "Connected Clients";
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''redis_connected_clients{instance=~"$instance"}''; })
      ];
    })

    (timeseries {
      title = "Memory Usage"; unit = "bytes";
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''redis_memory_used_bytes{instance=~"$instance"}''; legendFormat = "{{instance}} used"; })
        (q { expr = ''redis_config_maxmemory{instance=~"$instance"} > 0''; legendFormat = "{{instance}} maxmemory"; })
      ];
    })

    (timeseries {
      title = "Memory Fragmentation Ratio";
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''redis_allocator_frag_ratio{instance=~"$instance"}''; })
      ];
    })

    (timeseries {
      title = "Ops/sec"; unit = "ops";
      targets = [
        (q { expr = ''rate(redis_commands_processed_total{instance=~"$instance"}[$__rate_interval])''; })
      ];
    })

    (timeseries {
      title = "Keyspace Hit Rate"; unit = "percent"; min = 0; max = 100;
      targets = [
        (q { expr = ''rate(redis_keyspace_hits_total{instance=~"$instance"}[$__rate_interval]) / (rate(redis_keyspace_hits_total{instance=~"$instance"}[$__rate_interval]) + rate(redis_keyspace_misses_total{instance=~"$instance"}[$__rate_interval])) * 100''; })
      ];
    })

    (timeseries {
      title = "Blocked Clients";
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''redis_blocked_clients{instance=~"$instance"}''; })
      ];
    })

    (timeseries {
      title = "Replication";
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''redis_connected_slaves{instance=~"$instance"}''; legendFormat = "{{instance}} connected slaves"; })
        (q { expr = ''redis_connected_slave_lag_seconds{instance=~"$instance"}''; legendFormat = "{{instance}} slave lag {{slave_ip}}:{{slave_port}}"; })
      ];
    })

    (timeseries {
      title = "Evicted Keys"; unit = "ops";
      targets = [
        (q { expr = ''rate(redis_evicted_keys_total{instance=~"$instance"}[$__rate_interval])''; })
      ];
    })
  ];
}
