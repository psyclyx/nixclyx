{ mkDashboard, timeseries, table, q, qt, stdVars, thresholds
, organize, colorBgOverride, mappingOverride
, ... }:

mkDashboard {
  uid = "psyclyx-postgresql";
  title = "PostgreSQL";
  tags = [ "postgresql" "database" ];
  vars = stdVars "pg_up";

  panels = [
    (table {
      title = "Replication Status"; h = 4;
      targets = [
        (qt { expr = ''pg_replication_is_replica{instance=~"$instance"}''; })
        (qt { expr = ''pg_replication_lag_seconds{instance=~"$instance"}''; })
      ];
      transformations = [
        { id = "seriesToColumns"; options.byField = "instance"; }
        (organize {
          excludeByName = {
            "Time 1" = true; "Time 2" = true;
            "__name__ 1" = true; "__name__ 2" = true;
            "job 1" = true; "job 2" = true;
          };
          renameByName = {
            "instance" = "Instance";
            "Value #A" = "Is Replica";
            "Value #B" = "Lag (s)";
          };
        })
      ];
      overrides = [
        (mappingOverride "Is Replica" [
          { options = { "0" = { text = "Primary"; color = "green"; }; "1" = { text = "Replica"; color = "blue"; }; }; type = "value"; }
        ])
        (colorBgOverride "Is Replica")
      ];
    })

    (timeseries {
      title = "Connections";
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''pg_stat_activity_count{instance=~"$instance", state="active"}''; legendFormat = "{{instance}} active"; })
        (q { expr = ''pg_stat_activity_count{instance=~"$instance", state="idle"}''; legendFormat = "{{instance}} idle"; })
        (q { expr = ''pg_settings_max_connections{instance=~"$instance"}''; legendFormat = "{{instance}} max"; })
      ];
    })

    (timeseries {
      title = "Transactions/sec"; unit = "ops";
      targets = [
        (q { expr = ''rate(pg_stat_database_xact_commit{instance=~"$instance", datname!=""}[$__rate_interval])''; legendFormat = "{{instance}} {{datname}} commits"; })
        (q { expr = ''rate(pg_stat_database_xact_rollback{instance=~"$instance", datname!=""}[$__rate_interval])''; legendFormat = "{{instance}} {{datname}} rollbacks"; })
      ];
    })

    (timeseries {
      title = "Cache Hit Ratio"; unit = "percent"; min = 0; max = 100;
      thresholds = thresholds.cacheHitRatio;
      targets = [
        (q { expr = ''rate(pg_stat_database_blks_hit{instance=~"$instance", datname!=""}[$__rate_interval]) / (rate(pg_stat_database_blks_hit{instance=~"$instance", datname!=""}[$__rate_interval]) + rate(pg_stat_database_blks_read{instance=~"$instance", datname!=""}[$__rate_interval])) * 100''; legendFormat = "{{instance}} {{datname}}"; })
      ];
    })

    (timeseries {
      title = "Tuple Operations"; unit = "ops";
      targets = [
        (q { expr = ''rate(pg_stat_database_tup_inserted{instance=~"$instance", datname!=""}[$__rate_interval])''; legendFormat = "{{instance}} {{datname}} inserts"; })
        (q { expr = ''rate(pg_stat_database_tup_updated{instance=~"$instance", datname!=""}[$__rate_interval])''; legendFormat = "{{instance}} {{datname}} updates"; })
        (q { expr = ''rate(pg_stat_database_tup_deleted{instance=~"$instance", datname!=""}[$__rate_interval])''; legendFormat = "{{instance}} {{datname}} deletes"; })
        (q { expr = ''rate(pg_stat_database_tup_fetched{instance=~"$instance", datname!=""}[$__rate_interval])''; legendFormat = "{{instance}} {{datname}} fetched"; })
      ];
    })

    (timeseries {
      title = "Database Size"; unit = "bytes";
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''pg_database_size_bytes{instance=~"$instance", datname!=""}''; legendFormat = "{{instance}} {{datname}}"; })
      ];
    })

    (timeseries {
      title = "Temp Files"; unit = "bytes";
      targets = [
        (q { expr = ''rate(pg_stat_database_temp_bytes{instance=~"$instance", datname!=""}[$__rate_interval])''; legendFormat = "{{instance}} {{datname}} bytes/s"; })
        (q { expr = ''rate(pg_stat_database_temp_files{instance=~"$instance", datname!=""}[$__rate_interval])''; legendFormat = "{{instance}} {{datname}} files/s"; })
      ];
    })

    (timeseries {
      title = "WAL Size"; unit = "bytes";
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''pg_wal_size_bytes{instance=~"$instance"}''; })
      ];
    })

    (timeseries {
      title = "Deadlocks"; unit = "ops";
      targets = [
        (q { expr = ''rate(pg_stat_database_deadlocks{instance=~"$instance", datname!=""}[$__rate_interval])''; legendFormat = "{{instance}} {{datname}}"; })
      ];
    })

    (timeseries {
      title = "Checkpoints"; unit = "ops";
      targets = [
        (q { expr = ''rate(pg_stat_bgwriter_checkpoints_timed_total{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} timed"; })
        (q { expr = ''rate(pg_stat_bgwriter_checkpoints_req_total{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} requested"; })
      ];
    })

    (timeseries {
      title = "Dead Tuples (Top 10)";
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''topk(10, pg_stat_user_tables_n_dead_tup{instance=~"$instance"})''; legendFormat = "{{datname}}.{{schemaname}}.{{relname}}"; })
      ];
    })

    (timeseries {
      title = "Autovacuum Activity"; unit = "ops";
      targets = [
        (q { expr = ''sum by(instance) (rate(pg_stat_user_tables_autovacuum_count{instance=~"$instance"}[$__rate_interval]))''; legendFormat = "{{instance}} vacuums"; })
        (q { expr = ''sum by(instance) (rate(pg_stat_user_tables_autoanalyze_count{instance=~"$instance"}[$__rate_interval]))''; legendFormat = "{{instance}} analyzes"; })
      ];
    })

    (timeseries {
      title = "Scans (Seq vs Index)"; unit = "ops";
      targets = [
        (q { expr = ''sum by(instance) (rate(pg_stat_user_tables_seq_scan{instance=~"$instance"}[$__rate_interval]))''; legendFormat = "{{instance}} sequential"; })
        (q { expr = ''sum by(instance) (rate(pg_stat_user_tables_idx_scan{instance=~"$instance"}[$__rate_interval]))''; legendFormat = "{{instance}} index"; })
      ];
    })

    (timeseries {
      title = "Locks";
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''sum by(instance, mode) (pg_locks_count{instance=~"$instance", datname!=""})''; legendFormat = "{{instance}} {{mode}}"; })
      ];
    })
  ];
}
