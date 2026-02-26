{ mkDashboard, timeseries, table, bargauge, q, qt, stdVars, thresholds
, organize, colorBgOverride, mappingOverride
, ... }:

mkDashboard {
  uid = "psyclyx-haproxy";
  title = "HAProxy";
  tags = [ "haproxy" "loadbalancer" ];
  vars = stdVars "haproxy_up";

  panels = [
    (table {
      title = "Backend Status"; h = 4;
      targets = [
        (qt { expr = ''haproxy_server_status{instance=~"$instance"}''; })
      ];
      mappings = [
        { options = {
            "0" = { color = "red"; text = "DOWN"; };
            "1" = { color = "green"; text = "UP"; };
            "2" = { color = "yellow"; text = "NOLB"; };
            "3" = { color = "yellow"; text = "MAINT"; };
          }; type = "value"; }
      ];
      thresholds = thresholds.upDown;
      overrides = [ (colorBgOverride "Value") ];
      transformations = [
        (organize {
          excludeByName = { "Time" = true; "__name__" = true; "job" = true; };
          renameByName = {
            "instance" = "Instance";
            "proxy" = "Backend";
            "server" = "Server";
            "Value" = "Status";
          };
        })
      ];
    })

    (timeseries {
      title = "Current Sessions";
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''haproxy_frontend_current_sessions{instance=~"$instance"}''; legendFormat = "{{instance}} frontend {{proxy}}"; })
        (q { expr = ''haproxy_backend_current_sessions{instance=~"$instance"}''; legendFormat = "{{instance}} backend {{proxy}}"; })
      ];
    })

    (timeseries {
      title = "Request Rate"; unit = "ops";
      targets = [
        (q { expr = ''rate(haproxy_frontend_http_requests_total{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} {{proxy}}"; })
      ];
    })

    (timeseries {
      title = "Backend Response Time"; unit = "s";
      targets = [
        (q { expr = ''haproxy_backend_response_time_average_seconds{instance=~"$instance"}''; legendFormat = "{{instance}} {{proxy}}"; })
      ];
    })

    (timeseries {
      title = "Bytes In/Out"; unit = "bytes";
      targets = [
        (q { expr = ''rate(haproxy_frontend_bytes_in_total{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} {{proxy}} in"; })
        (q { expr = ''rate(haproxy_frontend_bytes_out_total{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} {{proxy}} out"; })
      ];
    })

    (timeseries {
      title = "Connection Errors"; unit = "ops";
      targets = [
        (q { expr = ''rate(haproxy_backend_connection_errors_total{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} {{proxy}} backend"; })
        (q { expr = ''rate(haproxy_frontend_request_errors_total{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} {{proxy}} frontend"; })
      ];
    })

    (timeseries {
      title = "Backend Queue";
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''haproxy_backend_current_queue{instance=~"$instance"}''; legendFormat = "{{instance}} {{proxy}}"; })
      ];
    })

    (timeseries {
      title = "HTTP Response Codes"; unit = "ops";
      targets = [
        (q { expr = ''rate(haproxy_frontend_http_responses_total{instance=~"$instance"}[$__rate_interval])''; legendFormat = "{{instance}} {{proxy}} {{code}}"; })
      ];
    })

    (timeseries {
      title = "Server Health";
      legendCalcs = [ "lastNotNull" ];
      targets = [
        (q { expr = ''haproxy_server_up{instance=~"$instance"}''; legendFormat = "{{instance}} {{proxy}}/{{server}}"; })
      ];
    })

    (bargauge {
      title = "Session Utilization";
      unit = "percent";
      targets = [
        (q { expr = ''haproxy_frontend_current_sessions{instance=~"$instance"} / haproxy_frontend_limit_sessions{instance=~"$instance"} * 100''; legendFormat = "{{instance}} {{proxy}}"; })
      ];
    })
  ];
}
