{ mkDashboard, timeseries, stat, table, q, qt, stdVars, thresholds
, organize, colorBgOverride, mappingOverride
, ... }:

mkDashboard {
  uid = "psyclyx-patroni";
  title = "Patroni";
  tags = [ "patroni" "postgresql" "ha" ];
  vars = stdVars "patroni_postgres_running";

  panels = [
    (table {
      title = "Cluster Roles"; h = 4;
      targets = [
        (qt { expr = ''patroni_primary{instance=~"$instance"}''; })
        (qt { expr = ''patroni_replica{instance=~"$instance"}''; })
        (qt { expr = ''patroni_postgres_running{instance=~"$instance"}''; })
      ];
      transformations = [
        { id = "seriesToColumns"; options.byField = "instance"; }
        (organize {
          excludeByName = {
            "Time 1" = true; "Time 2" = true; "Time 3" = true;
            "__name__ 1" = true; "__name__ 2" = true; "__name__ 3" = true;
            "job 1" = true; "job 2" = true; "job 3" = true;
          };
          renameByName = {
            "instance" = "Instance";
            "Value #A" = "Primary";
            "Value #B" = "Replica";
            "Value #C" = "PG Running";
          };
        })
      ];
      overrides = [
        (mappingOverride "Primary" [
          { options = { "0" = { text = "No"; color = "text"; }; "1" = { text = "Primary"; color = "green"; }; }; type = "value"; }
        ])
        (colorBgOverride "Primary")
        (mappingOverride "Replica" [
          { options = { "0" = { text = "No"; color = "text"; }; "1" = { text = "Replica"; color = "blue"; }; }; type = "value"; }
        ])
        (colorBgOverride "Replica")
        (mappingOverride "PG Running" [
          { options = { "0" = { text = "Down"; color = "red"; }; "1" = { text = "Running"; color = "green"; }; }; type = "value"; }
        ])
        (colorBgOverride "PG Running")
      ];
    })

    (timeseries {
      title = "Timeline";
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''patroni_postgres_timeline{instance=~"$instance"}''; })
      ];
    })

    (timeseries {
      title = "WAL Position"; unit = "bytes";
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''patroni_xlog_location{instance=~"$instance"}''; legendFormat = "{{instance}} location"; })
        (q { expr = ''patroni_xlog_received_location{instance=~"$instance"}''; legendFormat = "{{instance}} received"; })
        (q { expr = ''patroni_xlog_replayed_location{instance=~"$instance"}''; legendFormat = "{{instance}} replayed"; })
      ];
    })

    (timeseries {
      title = "Replication Lag"; unit = "s";
      targets = [
        (q { expr = ''time() - patroni_xlog_replayed_timestamp{instance=~"$instance"}''; legendFormat = "{{instance}} lag"; })
      ];
    })

    (timeseries {
      title = "DCS Last Seen"; unit = "s";
      targets = [
        (q { expr = ''time() - patroni_dcs_last_seen{instance=~"$instance"}''; })
      ];
    })

    (stat {
      title = "Pending Restarts"; w = 8; h = 4;
      thresholds = thresholds.upDown;
      targets = [
        (q { expr = ''patroni_pending_restart{instance=~"$instance"}''; })
      ];
    })

    (stat {
      title = "Cluster Unlocked"; w = 8; h = 4;
      thresholds = thresholds.mk [
        (thresholds.step "green" null)
        (thresholds.step "red" 1)
      ];
      targets = [
        (q { expr = ''patroni_cluster_unlocked{instance=~"$instance"}''; })
      ];
    })

    (stat {
      title = "Failsafe Mode"; w = 8; h = 4;
      thresholds = thresholds.mk [
        (thresholds.step "green" null)
        (thresholds.step "orange" 1)
      ];
      targets = [
        (q { expr = ''patroni_failsafe_mode_is_active{instance=~"$instance"}''; })
      ];
    })
  ];
}
