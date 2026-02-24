{ mkDashboard, timeseries, q, promDatasourceVar, queryVar, ... }:

mkDashboard {
  uid = "psyclyx-bcachefs";
  title = "Bcachefs";
  tags = [ "bcachefs" "storage" ];
  vars = [
    promDatasourceVar
    (queryVar { metric = "bcachefs_counter"; })
    (queryVar { name = "uuid"; metric = "bcachefs_counter"; label = "uuid";
                extraFilters = ''{instance=~"$instance"}''; })
  ];

  panels = [
    (timeseries {
      title = "Transaction Commit Rate"; unit = "ops";
      targets = [
        (q { expr = ''rate(bcachefs_counter{instance=~"$instance",uuid=~"$uuid",name="transaction_commit"}[$__rate_interval])''; legendFormat = "{{instance}} {{uuid}} commit"; })
      ];
    })

    (timeseries {
      title = "Transaction Restarts"; unit = "ops";
      targets = [
        (q { expr = ''sum by(instance, uuid) (rate(bcachefs_counter{instance=~"$instance",uuid=~"$uuid",name=~"trans_restart_.*"}[$__rate_interval]))''; legendFormat = "{{instance}} {{uuid}} restarts"; })
      ];
    })

    (timeseries {
      title = "Journal Writes"; unit = "ops";
      targets = [
        (q { expr = ''rate(bcachefs_counter{instance=~"$instance",uuid=~"$uuid",name="journal_write"}[$__rate_interval])''; legendFormat = "{{instance}} {{uuid}} journal_write"; })
      ];
    })

    (timeseries {
      title = "Btree Operations"; unit = "ops";
      targets = [
        (q { expr = ''rate(bcachefs_counter{instance=~"$instance",uuid=~"$uuid",name="btree_node_read"}[$__rate_interval])''; legendFormat = "{{instance}} {{uuid}} read"; })
        (q { expr = ''rate(bcachefs_counter{instance=~"$instance",uuid=~"$uuid",name="btree_node_write"}[$__rate_interval])''; legendFormat = "{{instance}} {{uuid}} write"; })
        (q { expr = ''rate(bcachefs_counter{instance=~"$instance",uuid=~"$uuid",name="btree_node_split"}[$__rate_interval])''; legendFormat = "{{instance}} {{uuid}} split"; })
        (q { expr = ''rate(bcachefs_counter{instance=~"$instance",uuid=~"$uuid",name="btree_node_compact"}[$__rate_interval])''; legendFormat = "{{instance}} {{uuid}} compact"; })
      ];
    })

    (timeseries {
      title = "Write Buffer Flushes"; unit = "ops";
      targets = [
        (q { expr = ''rate(bcachefs_counter{instance=~"$instance",uuid=~"$uuid",name="write_buffer_flush"}[$__rate_interval])''; legendFormat = "{{instance}} {{uuid}} wb_flush"; })
      ];
    })
  ];
}
