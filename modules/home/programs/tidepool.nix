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
    sortedMonitors =
      lib.sort (a: b: a.position.x < b.position.x)
      (lib.attrValues (lib.filterAttrs (_: m: m.enable) monitors));
    c = config.lib.stylix.colors;

    fuzzel-dmenu = "${lib.getExe config.programs.fuzzel.package} --dmenu";
    rofi-rbw = lib.getExe pkgs.rofi-rbw-wayland;
    grim = lib.getExe pkgs.grim;
    notify-send = lib.getExe' pkgs.libnotify "notify-send";
    slurp = lib.getExe pkgs.slurp;
    wl-copy = lib.getExe' pkgs.wl-clipboard "wl-copy";

    wl-paste = lib.getExe' pkgs.wl-clipboard "wl-paste";
    ssh-keygen = "${pkgs.openssh}/bin/ssh-keygen";

    sign-clipboard = pkgs.writeShellScriptBin "tidepool-sign-clipboard" ''
      set -euo pipefail

      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/sign-clipboard"
      mkdir -p "$state_dir"
      ns_history="$state_dir/namespaces"
      touch "$ns_history"

      # 1. Check clipboard
      challenge=$(${wl-paste} --no-newline 2>/dev/null || true)
      if [ -z "$challenge" ]; then
        ${notify-send} -u critical "Sign" "Clipboard is empty"
        exit 1
      fi

      # 2. Pick key
      keys=""
      for f in ~/.ssh/id_*; do
        [ -f "$f" ] || continue
        [[ "$f" == *.pub ]] && continue
        keys="$keys''${keys:+$'\n'}$(basename "$f")"
      done
      if [ -z "$keys" ]; then
        ${notify-send} -u critical "Sign" "No SSH keys found"
        exit 1
      fi
      key=$(echo "$keys" | ${fuzzel-dmenu} -p "Key: ") || exit 0

      # 3. Pick namespace (recent first, then type custom)
      recent=$(tac "$ns_history" | awk '!seen[$0]++' | head -10)
      ns=$(echo "$recent" | ${fuzzel-dmenu} -p "Namespace: ") || exit 0
      if [ -z "$ns" ]; then
        ${notify-send} -u critical "Sign" "No namespace"
        exit 1
      fi

      # Update history
      echo "$ns" >> "$ns_history"
      # Keep last 100 entries
      tail -100 "$ns_history" > "$ns_history.tmp" && mv "$ns_history.tmp" "$ns_history"

      # 4. Sign
      sig=$(echo -n "$challenge" | ${ssh-keygen} -Y sign -f "$HOME/.ssh/$key" -n "$ns" 2>/dev/null)
      if [ $? -ne 0 ] || [ -z "$sig" ]; then
        ${notify-send} -u critical "Sign" "Signing failed ($key / $ns)"
        exit 1
      fi
      echo -n "$sig" | ${wl-copy}
      ${notify-send} "Sign" "Signed with $key (ns: $ns)"
    '';

    screenshot-menu = pkgs.writeShellScriptBin "tidepool-screenshot-menu" ''
      options="Full Screen\nSelection\nFull Screen (Clipboard)\nSelection (Clipboard)"
      chosen=$(echo -e "$options" | ${fuzzel-dmenu} -p "Screenshot: ")
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

  in {
    home.packages = [
      pkgs.grim
      pkgs.slurp
      pkgs.libnotify
      pkgs.wl-clipboard
      pkgs.playerctl
      screenshot-menu
      sign-clipboard
    ];

    psyclyx.home.programs.shoal.enable = lib.mkDefault true;
    psyclyx.home.programs.fuzzel.enable = lib.mkDefault true;

    services.tidepool = {
      enable = true;
      package = pkgs.psyclyx.tidepool;

      outputOrder =
        lib.imap1 (i: m: {
          match = m.identifier;
          tag = i;
        })
        sortedMonitors;

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
        # Absorb / Eject / Expel
        "super+ctrl+h" = "actions/absorb-left";
        "super+ctrl+l" = "actions/absorb-right";
        "super+ctrl+j" = "actions/absorb-down";
        "super+ctrl+k" = "actions/absorb-up";
        "super+ctrl+space" = "actions/eject";
        "super+ctrl+shift+h" = "actions/expel-left";
        "super+ctrl+shift+l" = "actions/expel-right";
        "super+ctrl+shift+j" = "actions/expel-down";
        "super+ctrl+shift+k" = "actions/expel-up";
        # Width
        "super+r" = "actions/grow";
        # Tabs
        "super+t" = "actions/toggle-split-tabbed";
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
        # Fullscreen
        "super+slash" = "actions/toggle-fullscreen";
        # Float
        "super+f" = "actions/toggle-focus-float";
        "super+shift+f" = "actions/toggle-float";
        "super+ctrl+f" = "actions/gather-floats";
        # Resize
        "super+alt+h" = "actions/shrink-width";
        "super+alt+l" = "actions/grow-width";
        "super+alt+k" = "actions/shrink-height";
        "super+alt+j" = "actions/grow-height";
        "super+alt+r" = "actions/reset-size";
        # Media
        "XF86AudioRaiseVolume" = ''(actions/spawn "pactl" "set-sink-volume" "@DEFAULT_SINK@" "+5%")'';
        "XF86AudioLowerVolume" = ''(actions/spawn "pactl" "set-sink-volume" "@DEFAULT_SINK@" "-5%")'';
        "XF86AudioMute" = ''(actions/spawn "pactl" "set-sink-mute" "@DEFAULT_SINK@" "toggle")'';
        "XF86AudioPlay" = ''(actions/spawn "playerctl" "play-pause")'';
        "XF86AudioNext" = ''(actions/spawn "playerctl" "next")'';
        "XF86AudioPrev" = ''(actions/spawn "playerctl" "previous")'';
        "XF86AudioStop" = ''(actions/spawn "playerctl" "stop")'';
        # Launchers
        "super+p" = ''(actions/spawn "${rofi-rbw}")'';
        "super+s" = ''(actions/spawn "${lib.getExe screenshot-menu}")'';
        "super+shift+s" = ''(actions/spawn "${lib.getExe sign-clipboard}")'';
      };
      pointerBindings = {
        "super+left" = "actions/pointer-move-float";
      };
      extraConfig = ''
        (put config :outer-padding 12)
        (put config :peek-width 16)
      '';
    };
  };
}
