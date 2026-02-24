{ mkDashboard, timeseries, table, bargauge, q, qt, stdVars, thresholds
, organize, colorBgOverride
, ... }:

mkDashboard {
  uid = "psyclyx-seaweedfs";
  title = "SeaweedFS";
  tags = [ "seaweedfs" "storage" ];
  vars = stdVars "SeaweedFS_master_is_leader";

  panels = [
    (table {
      title = "Master Leadership"; w = 12; h = 4;
      targets = [
        (qt { expr = ''SeaweedFS_master_is_leader{job="seaweedfs-master",instance=~"$instance"}''; })
      ];
      mappings = [
        { options = {
            "0" = { color = "yellow"; text = "Follower"; };
            "1" = { color = "green"; text = "Leader"; };
          }; type = "value"; }
      ];
      thresholds = thresholds.upDown;
      overrides = [ (colorBgOverride "Value") ];
      transformations = [
        (organize {
          excludeByName = { "Time" = true; "__name__" = true; "job" = true; };
          renameByName = { "instance" = "Instance"; "Value" = "Role"; };
        })
      ];
    })

    (timeseries {
      title = "Leader Changes"; w = 12; h = 4;
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''rate(SeaweedFS_master_leader_changes{instance=~"$instance"}[$__rate_interval])''; })
      ];
    })

    (timeseries {
      title = "Writable Volumes";
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''SeaweedFS_master_volume_layout_writable{instance=~"$instance"}''; legendFormat = "{{instance}} {{collection}}"; })
      ];
    })

    (bargauge {
      title = "Volume Disk Usage";
      unit = "percent";
      targets = [
        (q { expr = ''SeaweedFS_volumeServer_resource{job="seaweedfs-volume",instance=~"$instance",type="used"} / ignoring(type) SeaweedFS_volumeServer_resource{job="seaweedfs-volume",instance=~"$instance",type="all"} * 100''; legendFormat = "{{instance}} {{name}}"; })
      ];
    })

    (timeseries {
      title = "Total Data Size"; unit = "bytes";
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''SeaweedFS_volumeServer_total_disk_size{job="seaweedfs-volume",instance=~"$instance",type="normal"}''; legendFormat = "{{instance}} {{collection}}"; })
      ];
    })

    (timeseries {
      title = "Volume Count";
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''SeaweedFS_volumeServer_volumes{job="seaweedfs-volume",instance=~"$instance"}''; legendFormat = "{{instance}} {{collection}}"; })
      ];
    })

    (timeseries {
      title = "Volume Request Rate"; unit = "ops";
      targets = [
        (q { expr = ''rate(SeaweedFS_volumeServer_request_total{job="seaweedfs-volume",instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} {{type}} {{code}}"; })
      ];
    })

    (timeseries {
      title = "Filer Request Rate"; unit = "ops";
      targets = [
        (q { expr = ''rate(SeaweedFS_filerStore_request_total{job="seaweedfs-filer",instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} {{type}}"; })
      ];
    })

    (timeseries {
      title = "Volume Latency"; unit = "s";
      targets = [
        (q { expr = ''rate(SeaweedFS_volumeServer_request_seconds_sum{job="seaweedfs-volume",instance=~"$instance"}[$__rate_interval]) / rate(SeaweedFS_volumeServer_request_seconds_count{job="seaweedfs-volume",instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} {{type}}"; })
      ];
    })

    (timeseries {
      title = "Filer Latency"; unit = "s";
      targets = [
        (q { expr = ''rate(SeaweedFS_filerStore_request_seconds_sum{job="seaweedfs-filer",instance=~"$instance"}[$__rate_interval]) / rate(SeaweedFS_filerStore_request_seconds_count{job="seaweedfs-filer",instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} {{type}}"; })
      ];
    })

    (timeseries {
      title = "Pick-for-Write Errors"; unit = "ops";
      targets = [
        (q { expr = ''rate(SeaweedFS_master_pick_for_write_error{instance=~"$instance"}[$__rate_interval])''; })
      ];
    })

    (timeseries {
      title = "Read-Only Volumes";
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''SeaweedFS_volumeServer_read_only_volumes{instance=~"$instance"}''; })
      ];
    })
  ];
}
