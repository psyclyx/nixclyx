# Grafana dashboard DSL library
#
# Usage: each dashboard .nix file is a function that receives this attrset
# and returns a JSON-serializable dashboard via mkDashboard.
let
  _defaultThresholds = {
    mode = "absolute";
    steps = [
      { color = "green"; value = null; }
      { color = "yellow"; value = 70; }
      { color = "red"; value = 90; }
    ];
  };
in rec {
  # ---------------------------------------------------------------------------
  # Datasource helpers
  # ---------------------------------------------------------------------------
  dsVar = { type = "prometheus"; uid = "\${datasource}"; };
  dsFixed = uid: { type = "prometheus"; inherit uid; };

  # ---------------------------------------------------------------------------
  # Target helpers (auto-assigns refId via layoutPanels)
  # ---------------------------------------------------------------------------
  q = { expr, legendFormat ? "{{instance}}" }: {
    inherit expr legendFormat;
    _type = "range";
  };

  qt = { expr }: {
    inherit expr;
    format = "table";
    instant = true;
    _type = "table";
  };

  # ---------------------------------------------------------------------------
  # Template variable helpers
  # ---------------------------------------------------------------------------
  promDatasourceVar = {
    current = { selected = false; text = "Prometheus"; value = "psyclyx-prometheus"; };
    hide = 0;
    includeAll = false;
    name = "datasource";
    options = [];
    query = "prometheus";
    refresh = 1;
    type = "datasource";
  };

  queryVar = { name ? "instance", metric, label ? "instance", extraFilters ? "" }:
    let definition = "label_values(${metric}${extraFilters}, ${label})";
    in {
      current = {};
      datasource = dsVar;
      inherit definition;
      hide = 0;
      includeAll = true;
      multi = true;
      inherit name;
      query = { qryType = 1; query = definition; };
      refresh = 2;
      sort = 1;
      type = "query";
    };

  stdVars = metric: [ promDatasourceVar (queryVar { inherit metric; }) ];

  # ---------------------------------------------------------------------------
  # Threshold presets
  # ---------------------------------------------------------------------------
  thresholds = {
    step = color: value: { inherit color value; };
    mk = steps: { mode = "absolute"; inherit steps; };

    percentage = {
      mode = "absolute";
      steps = [
        { color = "green"; value = null; }
        { color = "yellow"; value = 70; }
        { color = "red"; value = 90; }
      ];
    };
    cpuTemp = {
      mode = "absolute";
      steps = [
        { color = "green"; value = null; }
        { color = "yellow"; value = 70; }
        { color = "red"; value = 85; }
      ];
    };
    diskTemp = {
      mode = "absolute";
      steps = [
        { color = "green"; value = null; }
        { color = "yellow"; value = 45; }
        { color = "red"; value = 55; }
      ];
    };
    ssdWear = {
      mode = "absolute";
      steps = [
        { color = "green"; value = null; }
        { color = "yellow"; value = 80; }
        { color = "red"; value = 95; }
      ];
    };
    upDown = {
      mode = "absolute";
      steps = [
        { color = "red"; value = null; }
        { color = "green"; value = 1; }
      ];
    };
    highIsGood = {
      mode = "absolute";
      steps = [
        { color = "red"; value = null; }
        { color = "yellow"; value = 80; }
        { color = "green"; value = 95; }
      ];
    };
    cacheHitRatio = {
      mode = "absolute";
      steps = [
        { color = "red"; value = null; }
        { color = "yellow"; value = 95; }
        { color = "green"; value = 99; }
      ];
    };
  };

  # ---------------------------------------------------------------------------
  # Table transformation / override helpers
  # ---------------------------------------------------------------------------
  seriesToColumns = byField: { id = "seriesToColumns"; options = { inherit byField; }; };

  organize = { excludeByName ? {}, renameByName ? {}, indexByName ? {} }:
    { id = "organize"; options =
        { inherit excludeByName renameByName; }
        // (if indexByName == {} then {} else { inherit indexByName; });
    };

  colorBgOverride = field: {
    matcher = { id = "byName"; options = field; };
    properties = [
      { id = "custom.cellOptions"; value = { mode = "basic"; type = "color-background"; }; }
    ];
  };

  thresholdOverride = field: thr: {
    matcher = { id = "byName"; options = field; };
    properties = [
      { id = "thresholds"; value = thr; }
      { id = "custom.cellOptions"; value = { mode = "basic"; type = "color-background"; }; }
    ];
  };

  unitOverride = field: unit: {
    matcher = { id = "byName"; options = field; };
    properties = [ { id = "unit"; value = unit; } ];
  };

  mappingOverride = field: mappings: {
    matcher = { id = "byName"; options = field; };
    properties = [ { id = "mappings"; value = mappings; } ];
  };

  # ---------------------------------------------------------------------------
  # Panel constructors
  # ---------------------------------------------------------------------------

  timeseries = {
    title,
    targets,
    unit ? "short",
    w ? 12,
    h ? 8,
    min ? null,
    max ? null,
    thresholds ? null,
    legendCalcs ? [ "mean" "lastNotNull" ],
    fillOpacity ? 20,
    datasource ? dsVar,
    extraFieldConfig ? {},
    extraOptions ? {},
  }: {
    _w = w; _h = h;
    type = "timeseries";
    inherit title targets datasource;
    fieldConfig = {
      defaults = {
        color.mode = "palette-classic";
        custom = {
          axisBorderShow = false;
          axisCenteredZero = false;
          axisLabel = "";
          inherit fillOpacity;
          lineWidth = 1;
          scaleDistribution.type = "linear";
          showPoints = "never";
        };
        inherit unit;
      } // (if min != null then { inherit min; } else {})
        // (if max != null then { inherit max; } else {})
        // (if thresholds != null then { inherit thresholds; } else {});
    } // extraFieldConfig;
    options = {
      legend = {
        calcs = legendCalcs;
        displayMode = "table";
        placement = "bottom";
      };
      tooltip = { mode = "multi"; sort = "desc"; };
    } // extraOptions;
  };

  table = {
    title,
    targets,
    w ? 24,
    h ? 8,
    overrides ? [],
    transformations ? [],
    mappings ? [],
    thresholds ? null,
    datasource ? dsVar,
    extraFieldConfig ? {},
    extraOptions ? {},
  }: {
    _w = w; _h = h;
    type = "table";
    inherit title targets datasource transformations;
    fieldConfig = {
      defaults = {
        custom = {
          align = "auto";
          cellOptions.type = "auto";
          inspect = false;
        };
        inherit mappings;
      } // (if thresholds != null then { inherit thresholds; } else {
        thresholds = { mode = "absolute"; steps = [ { color = "green"; value = null; } ]; };
      });
      inherit overrides;
    } // extraFieldConfig;
    options = {
      showHeader = true;
      cellHeight = "sm";
      footer.show = false;
    } // extraOptions;
  };

  bargauge = {
    title,
    targets,
    unit ? "percent",
    w ? 12,
    h ? 8,
    min ? 0,
    max ? 100,
    thresholds ? _defaultThresholds,
    colorMode ? "continuous-BlYlRd",
    datasource ? dsVar,
    extraFieldConfig ? {},
    extraOptions ? {},
  }: {
    _w = w; _h = h;
    type = "bargauge";
    inherit title targets datasource;
    fieldConfig = {
      defaults = {
        color.mode = colorMode;
        inherit min max thresholds unit;
      };
    } // extraFieldConfig;
    options = {
      displayMode = "lcd";
      minVizHeight = 10;
      minVizWidth = 0;
      namePlacement = "auto";
      orientation = "horizontal";
      reduceOptions = { calcs = [ "lastNotNull" ]; fields = ""; values = false; };
      showUnfilled = true;
      valueMode = "color";
    } // extraOptions;
  };

  stat = {
    title,
    targets,
    unit ? "short",
    w ? 4,
    h ? 3,
    thresholds ? null,
    colorMode ? "value",
    graphMode ? "area",
    textMode ? "auto",
    datasource ? dsVar,
    extraFieldConfig ? {},
    extraOptions ? {},
  }: {
    _w = w; _h = h;
    type = "stat";
    inherit title targets datasource;
    fieldConfig = {
      defaults = {
        color.mode = "thresholds";
        inherit unit;
      } // (if thresholds != null then { inherit thresholds; } else {
        thresholds = { mode = "absolute"; steps = [{ color = "green"; value = null; }]; };
      });
    } // extraFieldConfig;
    options = {
      inherit colorMode graphMode textMode;
      reduceOptions = { calcs = [ "lastNotNull" ]; fields = ""; values = false; };
    } // extraOptions;
  };

  # ---------------------------------------------------------------------------
  # Layout engine
  # ---------------------------------------------------------------------------
  # Assigns sequential IDs, computes gridPos, and resolves target refIds.
  layoutPanels = panels:
    let
      alphabet = [ "A" "B" "C" "D" "E" "F" "G" "H" "I" "J" "K" "L" "M" "N" "O" "P" "Q" "R" "S" "T" "U" "V" "W" "X" "Y" "Z" ];
      resolveTargets = targets:
        let
          indexed = builtins.genList (i: {
            idx = i;
            t = builtins.elemAt targets i;
          }) (builtins.length targets);
        in map ({ idx, t }:
          let
            refId = builtins.elemAt alphabet idx;
            base = builtins.removeAttrs t [ "_type" ];
          in if (t._type or "range") == "table"
             then base // { inherit refId; }
             else base // { inherit refId; }
        ) indexed;

      go = idx: x: y: maxRowH: remaining:
        if remaining == [] then []
        else
          let
            panel = builtins.head remaining;
            rest = builtins.tail remaining;
            pw = panel._w or 12;
            ph = panel._h or 8;
            # Does it fit on the current row?
            fitsOnRow = x + pw <= 24;
            newX = if fitsOnRow then x else 0;
            newY = if fitsOnRow then y else y + maxRowH;
            newMaxH = if fitsOnRow then (if ph > maxRowH then ph else maxRowH) else ph;
            built = (builtins.removeAttrs panel [ "_w" "_h" ]) // {
              id = idx;
              gridPos = { w = pw; h = ph; x = newX; y = newY; };
              targets = resolveTargets (panel.targets or []);
            };
          in [ built ] ++ go (idx + 1) (newX + pw) newY newMaxH rest;
    in go 1 0 0 0 panels;

  # ---------------------------------------------------------------------------
  # Dashboard builder
  # ---------------------------------------------------------------------------
  mkDashboard = {
    uid,
    title,
    tags ? [],
    panels,
    vars ? [],
    refresh ? "30s",
    time ? { from = "now-6h"; to = "now"; },
  }: {
    annotations.list = [
      {
        builtIn = 1;
        datasource = { type = "grafana"; uid = "-- Grafana --"; };
        enable = true;
        hide = true;
        iconColor = "rgba(0, 211, 255, 1)";
        name = "Annotations & Alerts";
        type = "dashboard";
      }
    ];
    editable = false;
    fiscalYearStartMonth = 0;
    graphTooltip = 1;
    links = [];
    panels = layoutPanels panels;
    inherit refresh;
    schemaVersion = 39;
    inherit tags;
    templating.list = vars;
    inherit time title uid;
  };
}
