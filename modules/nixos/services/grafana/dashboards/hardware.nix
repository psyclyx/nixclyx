{ mkDashboard, timeseries, table, bargauge, q, qt, stdVars, thresholds
, organize, colorBgOverride
, ... }:

mkDashboard {
  uid = "psyclyx-hardware";
  title = "Hardware";
  tags = [ "hardware" "smart" ];
  vars = stdVars "node_uname_info";

  panels = [
    (table {
      title = "SMART Status"; h = 6;
      mappings = [
        { options = { "0" = { color = "green"; text = "OK"; }; "1" = { color = "red"; text = "FAIL"; }; }; type = "value"; }
      ];
      thresholds = thresholds.mk [
        (thresholds.step "green" null)
        (thresholds.step "red" 1)
      ];
      overrides = [ (colorBgOverride "Status") ];
      targets = [
        (qt { expr = ''smartctl_device_smartctl_exit_status{instance=~"$instance"}''; })
      ];
      transformations = [
        (organize {
          excludeByName = { "Time" = true; "__name__" = true; "job" = true; };
          renameByName = {
            "instance" = "Instance"; "device" = "Device"; "model_name" = "Model";
            "serial_number" = "Serial"; "firmware_version" = "Firmware"; "Value" = "Status";
          };
        })
      ];
    })

    (timeseries {
      title = "CPU Temperatures"; unit = "celsius";
      thresholds = thresholds.cpuTemp;
      targets = [
        (q { expr = ''node_hwmon_temp_celsius{instance=~"$instance",chip=~".*coretemp.*|.*k10temp.*"}''; legendFormat = "{{instance}} {{chip}} {{sensor}}"; })
      ];
    })

    (timeseries {
      title = "Disk Temperatures"; unit = "celsius";
      thresholds = thresholds.diskTemp;
      targets = [
        (q { expr = ''smartctl_device_temperature{instance=~"$instance",temperature_type="current"}''; legendFormat = "{{instance}} {{device}} {{model_name}}"; })
      ];
    })

    (bargauge {
      title = "SSD/NVMe Wear (% Life Used)"; h = 6;
      thresholds = thresholds.ssdWear;
      colorMode = "continuous-RdYlGr";
      targets = [
        (q { expr = ''smartctl_device_percentage_used{instance=~"$instance"}''; legendFormat = "{{instance}} {{device}} {{model_name}}"; })
      ];
    })

    (timeseries {
      title = "Power-On Hours"; unit = "h"; h = 6;
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''smartctl_device_power_on_seconds{instance=~"$instance"} / 3600''; legendFormat = "{{instance}} {{device}} {{model_name}}"; })
      ];
    })

    (timeseries {
      title = "Power Draw"; unit = "watt";
      targets = [
        (q { expr = ''node_hwmon_power_average_watt{instance=~"$instance"}''; legendFormat = "{{instance}} {{chip}} {{sensor}}"; })
      ];
    })

    (timeseries {
      title = "Fan Speeds"; unit = "rpm";
      targets = [
        (q { expr = ''node_hwmon_fan_rpm{instance=~"$instance"}''; legendFormat = "{{instance}} {{chip}} {{sensor}}"; })
      ];
    })

    (timeseries {
      title = "Error Indicators"; w = 24;
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''smartctl_device_media_errors{instance=~"$instance"}''; legendFormat = "{{instance}} {{device}} media errors"; })
        (q { expr = ''smartctl_device_error_log_count{instance=~"$instance"}''; legendFormat = "{{instance}} {{device}} error log entries"; })
        (q { expr = ''smartctl_device_attribute{instance=~"$instance",attribute_name="Reallocated_Sector_Ct",attribute_value_type="raw"}''; legendFormat = "{{instance}} {{device}} reallocated sectors"; })
        (q { expr = ''smartctl_device_attribute{instance=~"$instance",attribute_name="Current_Pending_Sector",attribute_value_type="raw"}''; legendFormat = "{{instance}} {{device}} pending sectors"; })
      ];
    })

    (timeseries {
      title = "EDAC Errors";
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''node_edac_correctable_errors_total{instance=~"$instance"}''; legendFormat = "{{instance}} correctable {{controller}}:{{csrow}}"; })
        (q { expr = ''node_edac_uncorrectable_errors_total{instance=~"$instance"}''; legendFormat = "{{instance}} uncorrectable {{controller}}:{{csrow}}"; })
      ];
    })

    (timeseries {
      title = "Bonding Status";
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''node_bonding_active{instance=~"$instance"}''; legendFormat = "{{instance}} {{master}} active"; })
        (q { expr = ''node_bonding_slaves{instance=~"$instance"}''; legendFormat = "{{instance}} {{master}} total"; })
      ];
    })
  ];
}
