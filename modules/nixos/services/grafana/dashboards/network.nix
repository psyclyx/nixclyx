{ mkDashboard, timeseries, table, q, qt, stdVars
, organize, colorBgOverride
, ... }:

mkDashboard {
  uid = "psyclyx-network";
  title = "Network";
  tags = [ "network" "snmp" ];
  vars = stdVars "ifOperStatus";

  panels = [
    (timeseries {
      title = "Inbound Throughput"; unit = "bps";
      targets = [
        (q { expr = ''rate(ifHCInOctets{instance=~"$instance"}[$__rate_interval]) * 8''; legendFormat = "{{instance}} {{ifName}}"; })
      ];
    })

    (timeseries {
      title = "Outbound Throughput"; unit = "bps";
      targets = [
        (q { expr = ''rate(ifHCOutOctets{instance=~"$instance"}[$__rate_interval]) * 8''; legendFormat = "{{instance}} {{ifName}}"; })
      ];
    })

    (table {
      title = "Interface Status";
      mappings = [
        { options = {
            "1" = { color = "green"; text = "Up"; };
            "2" = { color = "red"; text = "Down"; };
            "3" = { color = "yellow"; text = "Testing"; };
          }; type = "value"; }
      ];
      thresholds = { mode = "absolute"; steps = [
        { color = "green"; value = null; }
        { color = "red"; value = 2; }
      ]; };
      overrides = [ (colorBgOverride "Value") ];
      targets = [
        (qt { expr = ''ifOperStatus{instance=~"$instance"}''; })
      ];
      transformations = [
        (organize {
          excludeByName = { "Time" = true; "__name__" = true; "job" = true; };
          renameByName = {
            "instance" = "Device"; "ifName" = "Interface";
            "ifAlias" = "Alias"; "ifIndex" = "Index"; "Value" = "Status";
          };
        })
      ];
    })

    (timeseries {
      title = "Inbound Errors"; unit = "pps";
      targets = [
        (q { expr = ''rate(ifInErrors{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} {{ifName}}"; })
      ];
    })

    (timeseries {
      title = "Inbound Discards"; unit = "pps";
      targets = [
        (q { expr = ''rate(ifInDiscards{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} {{ifName}}"; })
      ];
    })

    (timeseries {
      title = "Outbound Errors"; unit = "pps";
      targets = [
        (q { expr = ''rate(ifOutErrors{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} {{ifName}}"; })
      ];
    })

    (timeseries {
      title = "Outbound Discards"; unit = "pps";
      targets = [
        (q { expr = ''rate(ifOutDiscards{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} {{ifName}}"; })
      ];
    })
  ];
}
