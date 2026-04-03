{
  path = ["psyclyx" "home" "programs" "tidepool"];
  description = "Tidepool window manager configuration";
  config = {
    config,
    lib,
    pkgs,
    ...
  }: let
    monitors = config.psyclyx.home.hardware.monitors;
    sortedMonitors = lib.sort (a: b: a.position.x < b.position.x)
      (lib.attrValues (lib.filterAttrs (_: m: m.enable) monitors));
    c = config.lib.stylix.colors;

    shoal-dmenu = "${lib.getExe config.programs.shoal.package} --dmenu";
    tidepoolmsg = lib.getExe' config.services.tidepool.package "tidepoolmsg";
    rofi-rbw = lib.getExe pkgs.rofi-rbw-wayland;
    grim = lib.getExe pkgs.grim;
    notify-send = lib.getExe' pkgs.libnotify "notify-send";
    slurp = lib.getExe pkgs.slurp;
    wl-copy = lib.getExe' pkgs.wl-clipboard "wl-copy";

    screenshot-menu = pkgs.writeShellScriptBin "tidepool-screenshot-menu" ''
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

  in {
    home.packages = [
      pkgs.grim
      pkgs.slurp
      pkgs.jq
      pkgs.libnotify
      pkgs.wl-clipboard
      screenshot-menu
    ];

    psyclyx.home.programs.shoal.enable = lib.mkDefault true;

    services.tidepool = {
      enable = true;
      package = pkgs.psyclyx.tidepool;

      outputOrder = lib.imap1 (i: m: {
        match = m.identifier;
        tag = i;
      }) sortedMonitors;

      keybindings = {
        "super+Return" = ''(actions/spawn "uwsm" "app" "--" "xdg-terminal-exec")'';
        "super+d" = ''(actions/spawn "fuzzel")'';
        "super+shift+q" = "actions/close-focused";
        # Directional focus
        "super+h" = "actions/focus-left";
        "super+l" = "actions/focus-right";
        "super+j" = "actions/focus-down";
        "super+k" = "actions/focus-up";
        # Directional swap
        "super+shift+h" = "actions/swap-left";
        "super+shift+l" = "actions/swap-right";
        "super+shift+j" = "actions/swap-down";
        "super+shift+k" = "actions/swap-up";
        # Join / Leave
        "super+ctrl+h" = "actions/join-left";
        "super+ctrl+l" = "actions/join-right";
        "super+ctrl+j" = "actions/join-down";
        "super+ctrl+k" = "actions/join-up";
        "super+ctrl+space" = "actions/leave";
        # Width
        "super+r" = "actions/grow";
        # Insert mode
        "super+i" = "actions/toggle-insert-mode";
        # Tabs
        "super+t" = "actions/make-tabbed";
        "super+shift+t" = "actions/make-split";
        "super+Tab" = "actions/focus-tab-next";
        "super+shift+Tab" = "actions/focus-tab-prev";
        # Output focus
        "super+comma" = "actions/focus-output-prev";
        "super+period" = "actions/focus-output-next";
        # Tags
        "super+1" = "(actions/focus-tag 1)";
        "super+2" = "(actions/focus-tag 2)";
        "super+3" = "(actions/focus-tag 3)";
        "super+4" = "(actions/focus-tag 4)";
        "super+5" = "(actions/focus-tag 5)";
        "super+shift+1" = "(actions/send-to-tag 1)";
        "super+shift+2" = "(actions/send-to-tag 2)";
        "super+shift+3" = "(actions/send-to-tag 3)";
        "super+shift+4" = "(actions/send-to-tag 4)";
        "super+shift+5" = "(actions/send-to-tag 5)";
        # Launchers
        "super+p" = ''(actions/spawn "${rofi-rbw}")'';
        "super+s" = ''(actions/spawn "${lib.getExe screenshot-menu}")'';
      };
      extraConfig = ''
        (put config :outer-padding 12)
        (put config :peek-width 16)
      '';
    };
  };
}
