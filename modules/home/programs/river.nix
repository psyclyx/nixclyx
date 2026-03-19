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

    shoal-dmenu = "${lib.getExe config.programs.shoal.package} --dmenu";
    rofi-rbw = lib.getExe pkgs.rofi-rbw-wayland;
    swaylock = lib.getExe config.programs.swaylock.package;
    grim = lib.getExe pkgs.grim;
    notify-send = lib.getExe' pkgs.libnotify "notify-send";
    slurp = lib.getExe pkgs.slurp;
    wayland-logout = lib.getExe pkgs.wayland-logout;
    wl-copy = lib.getExe' pkgs.wl-clipboard "wl-copy";
    tidepoolmsg = lib.getExe' config.services.tidepool.package "tidepoolmsg";

    power-menu = pkgs.writeShellScriptBin "river-power-menu" ''
      options="Lock\nLogout\nSuspend\nReboot\nShutdown"
      chosen=$(echo -e "$options" | ${shoal-dmenu} -p "Power: ")
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
      chosen=$(echo -e "$options" | ${shoal-dmenu} -p "Screenshot: ")
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

    jq = lib.getExe pkgs.jq;

    column = lib.getExe' pkgs.util-linux "column";

    action-menu = pkgs.writeShellScript "tidepool-action-menu" ''
      set -euo pipefail

      actions_json=$(${tidepoolmsg} eval '(print (ipc/list-actions))' | head -1)

      # Build parallel arrays: display (aligned columns) and data (name|spec)
      display=$(echo "$actions_json" | ${jq} -r '
        .[] | (.desc // .name) + "\t" + (.key // "")
      ' | ${column} -t -s $'\t')
      data=$(echo "$actions_json" | ${jq} -r '
        .[] | .name + "\t" + (.spec // [] | tojson)
      ')

      # Step 1: Pick an action
      chosen_line=$(echo "$display" | ${shoal-dmenu} -p "Action: ") || exit 0
      line_num=$(echo "$display" | grep -nxF "$chosen_line" | head -1 | cut -d: -f1)
      entry=$(echo "$data" | sed -n "''${line_num}p")
      action_name=$(echo "$entry" | cut -f1)
      spec_json=$(echo "$entry" | cut -f2)

      # Step 2: Collect args interactively based on spec
      args=""
      for spec_entry in $(echo "$spec_json" | ${jq} -c '.[]'); do
        spec_type=$(echo "$spec_entry" | ${jq} -r 'if type == "string" then . else .[0] end')

        case "$spec_type" in
          resolver)
            # Show directions + special options
            pick=$(printf '%s\n' left right up down next prev last "mark..." "wid..." \
              | ${shoal-dmenu} -p "Target: ") || exit 0
            case "$pick" in
              "mark...")
                mark=$(echo "" | ${shoal-dmenu} -p "Mark name: ") || exit 0
                args="$args mark $mark"
                ;;
              "wid...")
                wid_pick=$(${tidepoolmsg} eval '(print (ipc/list-windows))' | head -1 \
                  | ${jq} -r '.[] | "\(.wid)|\(.app) — \(.title)"' \
                  | ${shoal-dmenu} -p "Window: ") || exit 0
                wid=$(echo "$wid_pick" | cut -d'|' -f1)
                args="$args wid $wid"
                ;;
              *)
                args="$args $pick"
                ;;
            esac
            ;;
          choice)
            options=$(echo "$spec_entry" | ${jq} -r '.[1:][]')
            pick=$(echo "$options" | ${shoal-dmenu} -p "$action_name: ") || exit 0
            args="$args $pick"
            ;;
          number)
            prompt=$(echo "$spec_entry" | ${jq} -r '.[1]')
            num=$(echo "" | ${shoal-dmenu} -p "$prompt: ") || exit 0
            args="$args $num"
            ;;
          string)
            prompt=$(echo "$spec_entry" | ${jq} -r '.[1]')
            str=$(echo "" | ${shoal-dmenu} -p "$prompt: ") || exit 0
            args="$args $str"
            ;;
        esac
      done

      # Step 3: Execute
      ${tidepoolmsg} action "$action_name" $args
    '';

    # Shortcut scripts: skip the first dmenu step for common operations
    summon-menu = pkgs.writeShellScript "tidepool-summon-menu" ''
      set -euo pipefail
      chosen=$(${tidepoolmsg} eval '(print (ipc/list-windows))' | head -1 \
        | ${jq} -r '.[] | "\(.wid)|\(.app) — \(.title)\(if .mark then " [\(.mark)]" else "" end)"' \
        | ${shoal-dmenu} -p "Summon: ") || exit 0
      wid=$(echo "$chosen" | cut -d'|' -f1)
      [ -n "$wid" ] && ${tidepoolmsg} action summon wid "$wid"
    '';

    mark-set-menu = pkgs.writeShellScript "tidepool-mark-set-menu" ''
      set -euo pipefail
      mark=$(echo "" | ${shoal-dmenu} -p "Mark: ") || exit 0
      [ -n "$mark" ] && ${tidepoolmsg} action mark-set "$mark"
    '';

    # Generic mark picker: lists existing marks, runs "$1 mark <name>"
    mark-pick = pkgs.writeShellScript "tidepool-mark-pick" ''
      set -euo pipefail
      action="''${1:?usage: tidepool-mark-pick <action>}"
      marks=$(${tidepoolmsg} eval '(print (ipc/list-marks))' | head -1 \
        | ${jq} -r '.[] | "\(.name)|\(.app) — \(.title)"')
      [ -z "$marks" ] && exit 0
      chosen=$(echo "$marks" | ${shoal-dmenu} -p "Mark: ") || exit 0
      name=$(echo "$chosen" | cut -d'|' -f1)
      [ -n "$name" ] && ${tidepoolmsg} action "$action" mark "$name"
    '';

    # River 0.4 init script: kept minimal. The only thing that must run
    # from river's process tree is uwsm finalize (sends sd_notify to mark
    # wayland-wm@river.service as ready). All session services are
    # orchestrated by systemd via graphical-session.target.
    initScript = pkgs.writeShellScript "river-init" ''
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
      (put config :border-sibling 0x${c.base04})
      (put config :border-width 4)
      (put config :outer-padding 4)
      (put config :inner-padding 8)
      (put config :default-layout :scroll)
      (put config :focus-follows-mouse false)
      (put config :warp-pointer true)
      (put config :wallpaper "${config.services.tidepool.wallpaper}")
${lib.optionalString (monitors != {}) ''
      # Output configuration (applied at startup via zwlr_output_manager_v1)
      (put config :outputs
        @{${lib.concatStringsSep "\n          " (lib.mapAttrsToList (_: m: let
            key = if m.identifier != null then m.identifier else m.connector;
          in
            if !m.enable
            then ''"${key}" @{:enable false}''
            else ''"${key}" @{${
              lib.optionalString (m.mode != null) ":mode [${toString m.mode.width} ${toString m.mode.height}] "
            }:pos [${toString m.position.x} ${toString m.position.y}] :scale ${toString m.scale}}''
          ) monitors)}})
''}
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
        # focus: directional (includes floats via geometry fallback)
        # swap: reorder tiled windows, nudge floating windows
        [:h {:mod4 true} (action/focus :left)]
        [:j {:mod4 true} (action/focus :down)]
        [:k {:mod4 true} (action/focus :up)]
        [:l {:mod4 true} (action/focus :right)]
        [:h {:mod4 true :shift true} (action/swap :left)]
        [:j {:mod4 true :shift true} (action/swap :down)]
        [:k {:mod4 true :shift true} (action/swap :up)]
        [:l {:mod4 true :shift true} (action/swap :right)]

        # Scroll layout column/row operations
        [:bracketleft {:mod4 true :shift true} (action/adjust-ratio -0.05)]
        [:bracketright {:mod4 true :shift true} (action/adjust-ratio 0.05)]
        [:h {:mod4 true :ctrl true} (action/consume-column :left)]
        [:l {:mod4 true :ctrl true} (action/consume-column :right)]
        [:j {:mod4 true :ctrl true} (action/expel-column)]
        [:k {:mod4 true :ctrl true} (action/equalize-column)]
        [:r {:mod4 true} (action/preset-column-width)]
        [:u {:mod4 true :ctrl true} (action/resize-window -0.1)]
        [:i {:mod4 true :ctrl true} (action/resize-window 0.1)]

        # Float resize (symmetric around center)
        [:h {:mod4 true :ctrl true :shift true} (action/float-resize :width -40)]
        [:l {:mod4 true :ctrl true :shift true} (action/float-resize :width 40)]
        [:j {:mod4 true :ctrl true :shift true} (action/float-resize :height 40)]
        [:k {:mod4 true :ctrl true :shift true} (action/float-resize :height -40)]
        [:c {:mod4 true} (action/float-center)]

        # Window state
        [:space {:mod4 true} (action/zoom)]
        [:semicolon {:mod4 true} (action/float)]
        [:slash {:mod4 true} (action/fullscreen)]

        # Output management
        [:period {:mod4 true} (action/focus-output)]
        [:period {:mod4 true :shift true} (action/send-to-output)]
        [:comma {:mod4 true} (action/focus-output :left)]
        [:comma {:mod4 true :shift true} (action/send-to-output)]

        # Focus and navigation
        [:o {:mod4 true} (action/focus :last)]
        [:bracketleft {:mod4 true} (action/nav-back)]
        [:bracketright {:mod4 true} (action/nav-forward)]

        # Scroll home
        [:grave {:mod4 true :ctrl true} (action/scroll-home)]
        [:grave {:mod4 true :ctrl true :shift true} (action/scroll-home-set)]

        # Marks and summon
        [:m {:mod4 true} (action/spawn ["${mark-set-menu}"])]
        [:m {:mod4 true :shift true} (action/spawn ["${mark-pick}" "focus"])]
        [:m {:mod4 true :ctrl true} (action/spawn ["${mark-pick}" "send-to"])]
        [:w {:mod4 true} (action/summon :last)]
        [:w {:mod4 true :shift true} (action/spawn ["${summon-menu}"])]
        [:w {:mod4 true :ctrl true} (action/spawn ["${mark-pick}" "summon"])]

        # Application launchers
        [:Return {:mod4 true} (action/signal ["open-launcher"])]
        [:i {:mod4 true} (action/spawn ["uwsm" "app" "--" "xdg-terminal-exec"])]
        [:u {:mod4 true} (action/spawn ["uwsm" "app" "--" "firefox"])]
        [:x {:mod4 true} (action/spawn ["uwsm" "app" "--" "${lib.getExe power-menu}"])]
        [:s {:mod4 true} (action/spawn ["uwsm" "app" "--" "${lib.getExe screenshot-menu}"])]
        [:p {:mod4 true} (action/spawn ["uwsm" "app" "--" "${rofi-rbw}"])]
        [:d {:mod4 true} (action/spawn ["${action-menu}"])]

        # Layout mode cycling
        [:Tab {:mod4 true} (action/cycle-layout :next)]
        [:Tab {:mod4 true :shift true} (action/cycle-layout :prev)]

        # Session
        [:q {:mod4 true :shift true} (action/close)]
        [:e {:mod4 true :shift true} (action/exit)]
        [:r {:mod4 true :shift true} (fn [seat binding] (reload-config))]

        # Scratchpad
        [:grave {:mod4 true} (action/toggle-scratchpad)]
        [:grave {:mod4 true :shift true} (action/send-to-scratchpad)]

        # All tags
        [:a {:mod4 true} (action/focus-all-tags)]

        # Media keys (no modifier)
        [:XF86AudioRaiseVolume {} (action/spawn ["pactl" "set-sink-volume" "@DEFAULT_SINK@" "+5%"])]
        [:XF86AudioLowerVolume {} (action/spawn ["pactl" "set-sink-volume" "@DEFAULT_SINK@" "-5%"])]
        [:XF86AudioMute {} (action/spawn ["pactl" "set-sink-mute" "@DEFAULT_SINK@" "toggle"])]
        [:XF86MonBrightnessUp {} (action/spawn ["brightnessctl" "set" "+10%"])]
        [:XF86MonBrightnessDown {} (action/spawn ["brightnessctl" "set" "10%-"])])

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
      pkgs.brightnessctl
      pkgs.pulseaudio
      pkgs.grim
      pkgs.slurp
      pkgs.jq
      pkgs.libnotify
      pkgs.wayland-logout
      power-menu
      screenshot-menu
    ];

    psyclyx.home = {
      programs = {
        alacritty.enable = lib.mkDefault true;
        tidepool.enable = lib.mkDefault true;
        shoal.enable = lib.mkDefault true;
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
