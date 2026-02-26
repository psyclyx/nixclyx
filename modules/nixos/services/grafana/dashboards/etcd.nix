{ mkDashboard, timeseries, table, q, qt, stdVars, thresholds
, organize, colorBgOverride
, ... }:

mkDashboard {
  uid = "psyclyx-etcd";
  title = "etcd";
  tags = [ "etcd" "consensus" ];
  vars = stdVars "etcd_server_has_leader";

  panels = [
    (table {
      title = "Leader Status"; w = 12; h = 4;
      targets = [
        (qt { expr = ''etcd_server_has_leader{instance=~"$instance"}''; })
      ];
      mappings = [
        { options = {
            "0" = { color = "red"; text = "No Leader"; };
            "1" = { color = "green"; text = "Has Leader"; };
          }; type = "value"; }
      ];
      thresholds = thresholds.upDown;
      overrides = [ (colorBgOverride "Value") ];
      transformations = [
        (organize {
          excludeByName = { "Time" = true; "__name__" = true; "job" = true; };
          renameByName = { "instance" = "Instance"; "Value" = "Leader"; };
        })
      ];
    })

    (timeseries {
      title = "Leader Changes"; w = 12; h = 4;
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''rate(etcd_server_leader_changes_seen_total{instance=~"$instance"}[$__rate_interval])''; })
      ];
    })

    (timeseries {
      title = "Proposals";
      targets = [
        (q { expr = ''rate(etcd_server_proposals_committed_total{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} committed"; })
        (q { expr = ''rate(etcd_server_proposals_applied_total{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} applied"; })
        (q { expr = ''etcd_server_proposals_pending{instance=~"$instance"}''; legendFormat = "{{instance}} pending"; })
        (q { expr = ''rate(etcd_server_proposals_failed_total{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} failed"; })
      ];
    })

    (timeseries {
      title = "DB Size"; unit = "bytes";
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''etcd_mvcc_db_total_size_in_bytes{instance=~"$instance"}''; })
      ];
    })

    (timeseries {
      title = "Keys";
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''etcd_debugging_mvcc_keys_total{instance=~"$instance"}''; })
      ];
    })

    (timeseries {
      title = "WAL Fsync Duration (p99)"; unit = "s";
      targets = [
        (q { expr = ''histogram_quantile(0.99, rate(etcd_disk_wal_fsync_duration_seconds_bucket{instance=~"$instance"}[$__rate_interval]))''; })
      ];
    })

    (timeseries {
      title = "Backend Commit Duration (p99)"; unit = "s";
      targets = [
        (q { expr = ''histogram_quantile(0.99, rate(etcd_disk_backend_commit_duration_seconds_bucket{instance=~"$instance"}[$__rate_interval]))''; })
      ];
    })

    (timeseries {
      title = "Client Traffic"; unit = "bytes";
      targets = [
        (q { expr = ''rate(etcd_network_client_grpc_received_bytes_total{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} received"; })
        (q { expr = ''rate(etcd_network_client_grpc_sent_bytes_total{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} sent"; })
      ];
    })

    (timeseries {
      title = "Peer Traffic"; unit = "bytes";
      targets = [
        (q { expr = ''rate(etcd_network_peer_received_bytes_total{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} received"; })
        (q { expr = ''rate(etcd_network_peer_sent_bytes_total{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} sent"; })
      ];
    })

    (timeseries {
      title = "gRPC Request Rate"; unit = "ops";
      targets = [
        (q { expr = ''rate(grpc_server_handled_total{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} {{grpc_method}}"; })
      ];
    })

    (timeseries {
      title = "Active Watchers";
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''etcd_debugging_mvcc_watcher_total{instance=~"$instance"}''; })
      ];
    })

    (timeseries {
      title = "Compaction Revision";
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''etcd_debugging_mvcc_compact_revision{instance=~"$instance"}''; legendFormat = "{{instance}} compact"; })
        (q { expr = ''etcd_debugging_mvcc_current_revision{instance=~"$instance"}''; legendFormat = "{{instance}} current"; })
      ];
    })
  ];
}
