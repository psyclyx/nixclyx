{
  path = [
    "psyclyx"
    "home"
    "programs"
    "river"
  ];
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
      # ctx and actions are provided by tidepool when loading this file.

      (def config (ctx :config))

      (def super {:mod4 true})
      (def super-shift {:mod4 true :shift true})

      (put config :xkb-bindings
        @[[:Return super ((actions :spawn) "foot")]
          [:q super-shift (actions :close-focused)]
          [:j super (actions :focus-next)]
          [:k super (actions :focus-prev)]
          [:J super-shift (actions :swap-next)]
          [:K super-shift (actions :swap-prev)]
          [:1 super ((actions :focus-tag) 1)]
          [:2 super ((actions :focus-tag) 2)]
          [:3 super ((actions :focus-tag) 3)]
          [:4 super ((actions :focus-tag) 4)]
          [:5 super ((actions :focus-tag) 5)]
          [:1 super-shift ((actions :send-to-tag) 1)]
          [:2 super-shift ((actions :send-to-tag) 2)]
          [:3 super-shift ((actions :send-to-tag) 3)]
          [:4 super-shift ((actions :send-to-tag) 4)]
          [:5 super-shift ((actions :send-to-tag) 5)]])
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

    systemd.user.services.swaybg = {
      Unit = {
        Description = "Wallpaper (swaybg)";
        PartOf = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${lib.getExe pkgs.swaybg} -i ${config.stylix.image} -m fill";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = ["graphical-session.target"];
    };
  };
}
