{ mkDashboard, timeseries, q, stdVars, ... }:

mkDashboard {
  uid = "psyclyx-zfs";
  title = "ZFS";
  tags = ["zfs" "storage"];
  vars = stdVars "node_zfs_arcstats_size";

  panels = [
    (timeseries {
      title = "ARC Size"; unit = "bytes";
      targets = [
        (q { expr = ''node_zfs_arcstats_size{instance=~"$instance"}''; legendFormat = "{{instance}} size"; })
        (q { expr = ''node_zfs_arcstats_c_max{instance=~"$instance"}''; legendFormat = "{{instance}} target max"; })
        (q { expr = ''node_zfs_arcstats_c_min{instance=~"$instance"}''; legendFormat = "{{instance}} target min"; })
      ];
    })

    (timeseries {
      title = "ARC Hit Ratio"; unit = "percentunit"; min = 0; max = 1;
      targets = [
        (q { expr = ''rate(node_zfs_arcstats_hits{instance=~"$instance"}[$__rate_interval]) / (rate(node_zfs_arcstats_hits{instance=~"$instance"}[$__rate_interval]) + rate(node_zfs_arcstats_misses{instance=~"$instance"}[$__rate_interval]))''; legendFormat = "{{instance}}"; })
      ];
    })

    (timeseries {
      title = "ARC Evictions"; unit = "ops";
      targets = [
        (q { expr = ''rate(node_zfs_arcstats_evict_skip{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} skip"; })
        (q { expr = ''rate(node_zfs_arcstats_evict_not_enough{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} not enough"; })
        (q { expr = ''rate(node_zfs_arcstats_evict_l2_skip{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} l2 skip"; })
      ];
    })

    (timeseries {
      title = "ARC MFU / MRU"; unit = "bytes";
      targets = [
        (q { expr = ''node_zfs_arcstats_mfu_size{instance=~"$instance"}''; legendFormat = "{{instance}} MFU"; })
        (q { expr = ''node_zfs_arcstats_mru_size{instance=~"$instance"}''; legendFormat = "{{instance}} MRU"; })
      ];
    })

    (timeseries {
      title = "DMU TX Rate"; unit = "ops";
      targets = [
        (q { expr = ''rate(node_zfs_dmu_tx_assigned{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} assigned"; })
        (q { expr = ''rate(node_zfs_dmu_tx_delay{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} delay"; })
        (q { expr = ''rate(node_zfs_dmu_tx_error{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} error"; })
      ];
    })

    (timeseries {
      title = "Prefetch Stats"; unit = "ops";
      targets = [
        (q { expr = ''rate(node_zfs_zfetchstats_hits{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} hits"; })
        (q { expr = ''rate(node_zfs_zfetchstats_misses{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} misses"; })
      ];
    })
  ];
}
