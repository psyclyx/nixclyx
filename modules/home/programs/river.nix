{
  path = ["psyclyx" "home" "programs" "river"];
  description = "River dynamic tiling compositor";
  config = {
    config,
    lib,
    pkgs,
    ...
  }: let
    monitors = config.psyclyx.home.hardware.monitors;
    c = config.lib.stylix.colors;
    opacity = builtins.toString config.stylix.opacity.desktop;

    fuzzel = lib.getExe config.programs.fuzzel.package;
    swaylock = lib.getExe config.programs.swaylock.package;
    grim = lib.getExe pkgs.grim;
    notify-send = lib.getExe' pkgs.libnotify "notify-send";
    slurp = lib.getExe pkgs.slurp;
    wayland-logout = lib.getExe pkgs.wayland-logout;
    wl-copy = lib.getExe' pkgs.wl-clipboard "wl-copy";
    wlr-randr = lib.getExe pkgs.wlr-randr;
    tidepool = lib.getExe pkgs.psyclyx.tidepool;
    inotifywait = lib.getExe' pkgs.inotify-tools "inotifywait";

    power-menu = pkgs.writeShellScriptBin "river-power-menu" ''
      options="Lock\nLogout\nSuspend\nReboot\nShutdown"
      chosen=$(echo -e "$options" | ${fuzzel} --dmenu --prompt "Power: ")
      case $chosen in
        "Lock") ${swaylock} ;;
        "Logout") ${wayland-logout} ;;
        "Suspend") systemctl suspend ;;
        "Shutdown") systemctl poweroff ;;
        "Reboot") systemctl reboot ;;
      esac
    '';

    screenshot-menu = pkgs.writeShellScriptBin "river-screenshot-menu" ''
      options="Full Screen\nSelection\nFull Screen (Clipboard)\nSelection (Clipboard)"
      chosen=$(echo -e "$options" | ${fuzzel} --dmenu --prompt "Screenshot: ")
      screenshot_dir="''${XDG_PICTURES_DIR:-$HOME/Pictures}/screenshots"
      mkdir -p "$screenshot_dir"
      filename="$screenshot_dir/screenshot-$(date +%Y%m%d-%H%M%S).png"
      case $chosen in
        "Full Screen")
          ${grim} "$filename"
          ${notify-send} "Screenshot saved" "$filename"
          ;;
        "Selection")
          ${grim} -g "$(${slurp})" "$filename" && ${notify-send} "Screenshot saved" "$filename"
          ;;
        "Full Screen (Clipboard)")
          ${grim} - | ${wl-copy} -t image/png
          ${notify-send} "Screenshot copied to clipboard"
          ;;
        "Selection (Clipboard)")
          ${grim} -g "$(${slurp})" - | ${wl-copy} -t image/png && ${notify-send} "Screenshot copied to clipboard"
          ;;
      esac
    '';

    mkTagsScript = { file, watchFile ? file }: pkgs.writeShellScript "waybar-tags" ''
      render_tags() {
        local file="$XDG_RUNTIME_DIR/${file}"
        local focused="" occupied="" active="true"
        if [ -f "$file" ]; then
          local content
          content=$(cat "$file")
          focused=$(echo "$content" | grep -o 'focused:[^ ]*' | cut -d: -f2)
          occupied=$(echo "$content" | grep -o 'occupied:[^ ]*' | cut -d: -f2)
          active=$(echo "$content" | grep -o 'active:[^ ]*' | cut -d: -f2)
        fi

        local IFS=','
        local -A focus_set occupy_set
        for t in $focused; do focus_set[$t]=1; done
        for t in $occupied; do occupy_set[$t]=1; done

        local focused_color='#${c.base07}' occupied_color='#${c.base05}' empty_color='#${c.base03}'
        if [ "$active" = "false" ]; then
          focused_color='#${c.base05}'
          occupied_color='#${c.base04}'
          empty_color='#${c.base02}'
        fi

        local out=""
        for i in 1 2 3 4 5 6 7 8 9 10; do
          local label=$i
          [ "$i" -eq 10 ] && label=0
          if [ "''${focus_set[$i]+x}" ]; then
            out="$out<span color='$focused_color' weight='bold'>$label</span> "
          elif [ "''${occupy_set[$i]+x}" ]; then
            out="$out<span color='$occupied_color'>$label</span> "
          else
            out="$out<span color='$empty_color'>$label</span> "
          fi
        done
        echo "$out"
      }

      render_tags
      while ${inotifywait} -qq -e close_write "$XDG_RUNTIME_DIR/${watchFile}"; do
        render_tags
      done
    '';

    tagsScript = mkTagsScript { file = "tidepool-tags"; };

    layoutScript = pkgs.writeShellScript "waybar-layout" ''
      cat "$XDG_RUNTIME_DIR/tidepool-layout" 2>/dev/null || echo "master-stack"
      while ${inotifywait} -qq -e close_write "$XDG_RUNTIME_DIR/tidepool-layout"; do
        cat "$XDG_RUNTIME_DIR/tidepool-layout"
      done
    '';

    waybarModules = {
      "custom/layout" = {
        exec = layoutScript;
        restart-interval = 5;
        format = "LAYOUT: {}";
      };
      pulseaudio = {
        format = "VOL: {volume}%";
        format-muted = "VOL: MUTE";
      };
      network = {
        format-wifi = "WIFI: {ifname} {ipaddr}/{cidr} {signalStrength}%";
        format-ethernet = "ETH: {ifname} {ipaddr}/{cidr}";
        format-linked = "NET: {ifname} (No IP)";
        format-disconnected = "NET: NONE";
        interval = 10;
      };
      backlight = {format = "BLT: {percent}%";};
      clock = {
        interval = 5;
        format = "{:%I:%M %m/%d/%y}";
      };
      cpu = {
        interval = 5;
        format = "CPU: {usage}% | {load}";
      };
      memory = {
        interval = 5;
        format = "MEM: {}%";
      };
      battery = {
        interval = 5;
        format = "BAT: {capacity}%";
      };
      tray = {
        icon-size = 24;
        spacing = 16;
      };
    };

    mkBarConfig = tagsExec: extra: {
      layer = "top";
      spacing = 16;
      modules-left = ["custom/tags" "custom/layout"];
      modules-center = ["clock"];
      modules-right = ["network" "backlight" "pulseaudio" "memory" "cpu" "battery" "tray"];
      "custom/tags" = {
        exec = tagsExec;
        restart-interval = 5;
        format = "{}";
        tooltip = false;
      };
    } // waybarModules // extra;

    enabledMonitors = lib.filterAttrs (_: m: m.enable) monitors;

    waybarConfig = pkgs.writeText "waybar-river.json" (builtins.toJSON (
      if enabledMonitors != {} then
        lib.mapAttrsToList (_: m: mkBarConfig
          (mkTagsScript {
            file = "tidepool-tags-${toString m.position.x},${toString m.position.y}";
            watchFile = "tidepool-tags-${toString m.position.x},${toString m.position.y}";
          })
          { output = m.connector; })
        enabledMonitors
      else
        mkBarConfig tagsScript {}
    ));

    waybarCss = pkgs.writeText "waybar-river.css" ''
      * {
          border: none;
          border-radius: 0;
      }
      window#waybar {
          background: alpha(#${c.base01}, ${opacity});
          color: #${c.base04};
          padding: 0;
          margin: 0;
      }
      tooltip {
          background-color: alpha(#${c.base01}, ${opacity});
      }
      tooltip label {
          color: #${c.base05};
      }
      #custom-tags,
      #custom-layout,
      #clock,
      #network,
      #backlight,
      #pulseaudio,
      #memory,
      #cpu,
      #battery,
      #tray {
          color: #${c.base05};
          padding: 0 8px;
      }
    '';

    outputSetup = lib.optionalString (monitors != {}) (
      lib.concatStringsSep "\n" (lib.mapAttrsToList (_: m:
        if !m.enable
        then "${wlr-randr} --output ${lib.escapeShellArg m.connector} --off"
        else
          lib.concatStringsSep " " (
            [wlr-randr "--output" (lib.escapeShellArg m.connector)]
            ++ lib.optionals (m.mode != null) [
              "--mode"
              ("${toString m.mode.width}x${toString m.mode.height}"
                + lib.optionalString (m.mode.refresh != null) "@${toString m.mode.refresh}")
            ]
            ++ ["--pos" "${toString m.position.x},${toString m.position.y}"]
            ++ ["--scale" (toString m.scale)]
          ))
        monitors)
    );

    # River 0.4 init script: minimal compositor bootstrap.
    # In 0.4, the WM (tidepool) handles borders, backgrounds, focus,
    # keybindings, and layout via the river-window-management protocol.
    # The init script only does output setup and launches services.
    # Note: tidepool must start before wlr-randr because River 0.4
    # only advertises wlr-output-management when a WM is connected.
    initScript = pkgs.writeShellScript "river-init" ''
      (
        while true; do
          ${tidepool}
          exit_code=$?
          [ "$exit_code" -ne 42 ] && break
        done
      ) &

      # Wait for tidepool to be ready (REPL socket appears)
      for i in $(seq 1 50); do
        [ -S "$XDG_RUNTIME_DIR/tidepool-$WAYLAND_DISPLAY" ] && break
        sleep 0.1
      done

      ${outputSetup}

      uwsm app -- waybar -c ${waybarConfig} -s ${waybarCss} &

      uwsm finalize
    '';

    # Tidepool config: keybindings, colors, layout, and rules.
    # This Janet file is loaded by tidepool at startup.
    tidepoolConfig = pkgs.writeText "tidepool-init.janet" ''
      # Colors from stylix
      (put config :background 0x${c.base00})
      (put config :border-focused 0x${c.base07})
      (put config :border-normal 0x${c.base03})
      (put config :border-urgent 0x${c.base08})
      (put config :border-width 4)
      (put config :outer-padding 4)
      (put config :inner-padding 8)
      (put config :main-ratio 0.55)

      # Window rules
      (array/push (config :rules)
        {:app-id "xdg-desktop-portal-gtk" :float true}
        {:app-id "firefox" :title "Library" :float true})

      # Config reload: destroys all bindings, re-reads init.janet, recreates bindings
      (def- reload-env (curenv))
      (defn reload-config []
        (each seat (wm :seats)
          (each b (seat :xkb-bindings) (:destroy (b :obj)))
          (each b (seat :pointer-bindings) (:destroy (b :obj)))
          (put seat :xkb-bindings @[])
          (put seat :pointer-bindings @[]))
        (put config :xkb-bindings @[])
        (put config :pointer-bindings @[])
        (put config :rules @[])
        (def config-dir (or (os/getenv "XDG_CONFIG_HOME")
                            (string (os/getenv "HOME") "/.config")))
        (dofile (string config-dir "/tidepool/init.janet") :env reload-env)
        (each seat (wm :seats)
          (each binding (config :xkb-bindings)
            (xkb-binding/create seat ;binding))
          (each binding (config :pointer-bindings)
            (pointer-binding/create seat ;binding))))

      # Keybindings
      (array/push
        (config :xkb-bindings)

        # Spatial window focus/swap (vim-style hjkl)
        [:h {:mod4 true} (action/focus :left)]
        [:j {:mod4 true} (action/focus :down)]
        [:k {:mod4 true} (action/focus :up)]
        [:l {:mod4 true} (action/focus :right)]
        [:h {:mod4 true :shift true} (action/swap :left)]
        [:j {:mod4 true :shift true} (action/swap :down)]
        [:k {:mod4 true :shift true} (action/swap :up)]
        [:l {:mod4 true :shift true} (action/swap :right)]
        [:bracketleft {:mod4 true} (action/adjust-ratio -0.05)]
        [:bracketright {:mod4 true} (action/adjust-ratio 0.05)]
        [:space {:mod4 true} (action/zoom)]
        [:semicolon {:mod4 true} (action/float)]
        [:slash {:mod4 true} (action/fullscreen)]

        # Output management
        [:period {:mod4 true} (action/focus-output)]
        [:comma {:mod4 true :shift true} (action/send-to-output)]

        # Application launchers
        [:Return {:mod4 true} (action/spawn ["uwsm" "app" "--" "${fuzzel}"])]
        [:i {:mod4 true} (action/spawn ["uwsm" "app" "--" "xdg-terminal-exec"])]
        [:u {:mod4 true} (action/spawn ["uwsm" "app" "--" "firefox"])]
        [:x {:mod4 true} (action/spawn ["uwsm" "app" "--" "${lib.getExe power-menu}"])]
        [:s {:mod4 true} (action/spawn ["uwsm" "app" "--" "${lib.getExe screenshot-menu}"])]

        # Layout cycling
        [:Tab {:mod4 true} (action/cycle-layout :next)]
        [:Tab {:mod4 true :shift true} (action/cycle-layout :prev)]

        # Main count adjustment
        [:equal {:mod4 true} (action/adjust-main-count 1)]
        [:minus {:mod4 true} (action/adjust-main-count -1)]

        # Session
        [:q {:mod4 true :shift true} (action/close)]
        [:e {:mod4 true :shift true} (action/exit)]
        [:r {:mod4 true :shift true} (fn [seat binding] (reload-config))]
        [:r {:mod4 true :ctrl true :shift true} (action/restart)]

        # Scratchpad
        [:grave {:mod4 true} (action/toggle-scratchpad)]
        [:grave {:mod4 true :shift true} (action/send-to-scratchpad)]

        # All tags
        [:a {:mod4 true} (action/focus-all-tags)]

        # Media keys (no modifier)
        [:XF86AudioRaiseVolume {} (action/spawn ["pactl" "set-sink-volume" "@DEFAULT_SINK@" "+5%"])]
        [:XF86AudioLowerVolume {} (action/spawn ["pactl" "set-sink-volume" "@DEFAULT_SINK@" "-5%"])]
        [:XF86AudioMute {} (action/spawn ["pactl" "set-sink-mute" "@DEFAULT_SINK@" "toggle"])]
        [:XF86MonBrightnessUp {} (action/spawn ["light" "-A" "10"])]
        [:XF86MonBrightnessDown {} (action/spawn ["light" "-U" "10"])])

      # Tag keybindings (1-9 → tags 1-9, 0 → tag 10)
      (for i 1 10
        (def keysym (keyword (string i)))
        (array/push
          (config :xkb-bindings)
          [keysym {:mod4 true} (action/focus-tag i)]
          [keysym {:mod4 true :shift true} (action/set-tag i)]
          [keysym {:mod4 true :ctrl true} (action/toggle-tag i)]))

      # Tag 10 on key 0
      (array/push
        (config :xkb-bindings)
        [:0 {:mod4 true} (action/focus-tag 10)]
        [:0 {:mod4 true :shift true} (action/set-tag 10)]
        [:0 {:mod4 true :ctrl true} (action/toggle-tag 10)])

      # Pointer bindings
      (array/push
        (config :pointer-bindings)
        [:left {:mod4 true} (action/pointer-move)]
        [:right {:mod4 true} (action/pointer-resize)])
    '';
  in {
    home.packages = [
      pkgs.pulseaudio
      pkgs.grim
      pkgs.slurp
      pkgs.libnotify
      pkgs.wayland-logout
      pkgs.inotify-tools
      pkgs.psyclyx.tidepool
      power-menu
      screenshot-menu
    ];

    psyclyx.home = {
      programs = {
        alacritty.enable = lib.mkDefault true;
        fuzzel.enable = lib.mkDefault true;
        waybar.enable = lib.mkDefault true;
      };
      services.mako.enable = lib.mkDefault true;
    };

    programs.swaylock = {
      enable = true;
      package = lib.mkDefault pkgs.swaylock-effects;
      settings = {
        indicator = true;
        screenshots = true;
        clock = true;
        show-failed-attempts = true;
        indicator-radius = lib.mkDefault 280;
        indicator-thickness = lib.mkDefault 4;
        effect-pixelate = lib.mkDefault 8;
        grace = lib.mkDefault 3;
      };
    };

    xdg.configFile."river/init" = {
      source = initScript;
      executable = true;
    };

    xdg.configFile."tidepool/init.janet" = {
      source = tidepoolConfig;
    };
  };
}
