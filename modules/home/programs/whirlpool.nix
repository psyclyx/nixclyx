{
  path = ["psyclyx" "home" "programs" "whirlpool"];
  description = "Whirlpool window manager and shell configuration";
  config = {
    config,
    lib,
    pkgs,
    ...
  }: let
    package = pkgs.psyclyx.whirlpool;

    fuzzel-dmenu = "${lib.getExe config.programs.fuzzel.package} --dmenu";
    rofi-rbw = lib.getExe pkgs.rofi-rbw-wayland;
    grim = lib.getExe pkgs.grim;
    notify-send = lib.getExe' pkgs.libnotify "notify-send";
    slurp = lib.getExe pkgs.slurp;
    wl-copy = lib.getExe' pkgs.wl-clipboard "wl-copy";

    wl-paste = lib.getExe' pkgs.wl-clipboard "wl-paste";
    ssh-keygen = "${pkgs.openssh}/bin/ssh-keygen";

    # Lua string-literal quoting for values interpolated into the generated
    # config below (paths only — no user-controlled input reaches this).
    luaStr = s: ''"${s}"'';
    spawnAction = args: ''action("spawn", ${lib.concatMapStringsSep ", " luaStr args})'';
    # Whirlpool's spawn is a direct fork of the whirlpool process, so anything
    # it launches lands in the whirlpool.service cgroup (logs attributed to
    # whirlpool, killed on whirlpool restart). Route GUI apps through
    # `uwsm app --` so they get their own app-*.scope under app.slice.
    # One-shot utilities (pactl/playerctl) and fuzzel stay bare.
    appSpawn = cmd: spawnAction (["uwsm" "app" "--"] ++ cmd);

    sign-clipboard = pkgs.writeShellScriptBin "whirlpool-sign-clipboard" ''
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

    screenshot-menu = pkgs.writeShellScriptBin "whirlpool-screenshot-menu" ''
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

    power-menu = pkgs.writeShellScriptBin "whirlpool-power-menu" ''
      options="Lock\nLogout\nSuspend\nReboot\nShutdown"
      chosen=$(echo -e "$options" | ${fuzzel-dmenu} --prompt "Power: ")
      case $chosen in
        "Lock") ${lib.getExe config.programs.swaylock.package} ;;
        "Logout") ${lib.getExe pkgs.wayland-logout} ;;
        "Suspend") systemctl suspend ;;
        "Shutdown") systemctl poweroff ;;
        "Reboot") systemctl reboot ;;
      esac
    '';

    # Ported from the retired Tidepool/Shoal config. Tidepool's height
    # resize, reset-size, toggle-focus-float, gather-floats, the
    # pointer-drag-to-float binding, and the outer-padding/peek-width layout
    # tuning have no equivalent in Whirlpool's scrolling layout yet — dropped
    # rather than approximated. Per-output tag pinning (Tidepool's
    # outputOrder) is also dropped for now; Whirlpool has no equivalent
    # concept yet.
    luaConfig = pkgs.writeText "whirlpool.lua" ''
      local whirlpool = require("whirlpool")
      local function action(name, ...)
        return { name = name, args = { ... } }
      end
      local function layout(name, ...)
        return action("layout", name, ...)
      end

      local super = { "super" }
      local super_shift = { "super", "shift" }
      local super_ctrl = { "super", "ctrl" }
      local super_ctrl_shift = { "super", "ctrl", "shift" }
      local super_alt = { "super", "alt" }

      local bindings = {
        { modifiers = super, key = "Return", action = ${appSpawn ["xdg-terminal-exec"]} },
        { modifiers = super, key = "d", action = action("spawn", "fuzzel") },
        { modifiers = super_shift, key = "q", action = layout("close-focused") },

        -- Directional focus
        { modifiers = super, key = "h", action = layout("focus-left") },
        { modifiers = super, key = "l", action = layout("focus-right") },
        { modifiers = super, key = "j", action = layout("focus-down") },
        { modifiers = super, key = "k", action = layout("focus-up") },

        -- Directional swap
        { modifiers = super_shift, key = "h", action = layout("swap-left") },
        { modifiers = super_shift, key = "l", action = layout("swap-right") },
        { modifiers = super_shift, key = "j", action = layout("swap-down") },
        { modifiers = super_shift, key = "k", action = layout("swap-up") },

        -- Absorb / Eject / Expel
        { modifiers = super_ctrl, key = "h", action = layout("absorb-left") },
        { modifiers = super_ctrl, key = "l", action = layout("absorb-right") },
        { modifiers = super_ctrl, key = "j", action = layout("absorb-down") },
        { modifiers = super_ctrl, key = "k", action = layout("absorb-up") },
        { modifiers = super_ctrl, key = "space", action = layout("eject") },
        { modifiers = super_ctrl_shift, key = "h", action = layout("expel-left") },
        { modifiers = super_ctrl_shift, key = "l", action = layout("expel-right") },
        { modifiers = super_ctrl_shift, key = "j", action = layout("expel-down") },
        { modifiers = super_ctrl_shift, key = "k", action = layout("expel-up") },

        -- Width, tabs, and outputs
        { modifiers = super, key = "r", action = layout("cycle-width") },
        { modifiers = super, key = "space", action = layout("cycle-container-mode") },
        { modifiers = super, key = "Tab", action = layout("focus-tab-next") },
        { modifiers = super_shift, key = "Tab", action = layout("focus-tab-prev") },
        { modifiers = super, key = "comma", action = layout("focus-output-prev") },
        { modifiers = super, key = "period", action = layout("focus-output-next") },

        -- Tags
        { modifiers = super, key = "1", action = layout("focus-tag", 1) },
        { modifiers = super, key = "2", action = layout("focus-tag", 2) },
        { modifiers = super, key = "3", action = layout("focus-tag", 3) },
        { modifiers = super, key = "4", action = layout("focus-tag", 4) },
        { modifiers = super, key = "5", action = layout("focus-tag", 5) },
        { modifiers = super_shift, key = "1", action = layout("send-to-tag", 1) },
        { modifiers = super_shift, key = "2", action = layout("send-to-tag", 2) },
        { modifiers = super_shift, key = "3", action = layout("send-to-tag", 3) },
        { modifiers = super_shift, key = "4", action = layout("send-to-tag", 4) },
        { modifiers = super_shift, key = "5", action = layout("send-to-tag", 5) },

        -- Fullscreen and floating windows
        { modifiers = super, key = "slash", action = layout("toggle-fullscreen") },

        -- The view: a window (or a row) that way, held until focus moves;
        -- Super+C, or Super+right-click, brings it back to the focused window.
        { modifiers = super, key = "Left", action = layout("pan-left") },
        { modifiers = super, key = "Right", action = layout("pan-right") },
        { modifiers = super, key = "Up", action = layout("pan-up") },
        { modifiers = super, key = "Down", action = layout("pan-down") },
        { modifiers = super, key = "c", action = layout("recenter") },
        { modifiers = super, key = "pointer:right", action = layout("recenter") },
        -- Super+drag moves a window from anywhere on it.
        { modifiers = super, key = "pointer:left", action = action("pointer-operation", "drag-window") },
        { modifiers = super, key = "f", action = layout("toggle-float") },
        { modifiers = super_shift, key = "f", action = layout("toggle-float") },

        -- Resize (width only — see the module comment on dropped height/reset-size)
        { modifiers = super_alt, key = "h", action = layout("shrink-width") },
        { modifiers = super_alt, key = "l", action = layout("grow-width") },

        -- Vim-style, one-shot mark prefixes. The following unmodified letter
        -- is captured only while the corresponding mode is active.
        { modifiers = super, key = "m", action = action("enter-mode", "mark") },
        { modifiers = super, key = "'", action = action("enter-mode", "focus-mark") },
        { modifiers = super_shift, key = "m", action = action("enter-mode", "summon-mark") },
        { modifiers = super_ctrl, key = "m", action = action("enter-mode", "send-to-mark") },
        { modifiers = super_ctrl_shift, key = "m", action = action("enter-mode", "clear-mark") },

        -- Media
        { key = "XF86AudioRaiseVolume", action = action("spawn", "pactl", "set-sink-volume", "@DEFAULT_SINK@", "+5%") },
        { key = "XF86AudioLowerVolume", action = action("spawn", "pactl", "set-sink-volume", "@DEFAULT_SINK@", "-5%") },
        { key = "XF86AudioMute", action = action("spawn", "pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle") },
        { key = "XF86AudioPlay", action = action("spawn", "playerctl", "play-pause") },
        { key = "XF86AudioNext", action = action("spawn", "playerctl", "next") },
        { key = "XF86AudioPrev", action = action("spawn", "playerctl", "previous") },
        { key = "XF86AudioStop", action = action("spawn", "playerctl", "stop") },

        -- Launchers
        { modifiers = super, key = "p", action = ${appSpawn [rofi-rbw]} },
        { modifiers = super, key = "s", action = ${appSpawn [(lib.getExe screenshot-menu)]} },
        { modifiers = super_shift, key = "s", action = ${appSpawn [(lib.getExe sign-clipboard)]} },
        { modifiers = super_shift, key = "e", action = ${appSpawn [(lib.getExe power-menu)]} },
      }

      local mark_modes = { "mark", "focus-mark", "summon-mark", "send-to-mark", "clear-mark" }
      for letter in string.gmatch("abcdefghijklmnopqrstuvwxyz", ".") do
        for _, mode in ipairs(mark_modes) do
          bindings[#bindings + 1] = { mode = mode, key = letter, action = layout(mode, letter) }
        end
      end
      for _, mode in ipairs(mark_modes) do
        bindings[#bindings + 1] = {
          mode = mode, key = "Escape", action = action("enter-mode", "default"),
        }
      end

      for _, binding in ipairs(bindings) do
        whirlpool.bind(binding.modifiers or {}, binding.key, binding.action, { mode = binding.mode })
      end

      -- `lib.*` is Whirlpool's example library, linked beside this file.
      whirlpool.layout("lib.scrolling", { widths = { 0.25, 1 / 3, 0.5, 2 / 3, 0.75, 1 } })

      -- Every source lib.bar draws from (temperatures, GPU, ...).
      require("lib.sources").register()

      local bar = {
        edge = "bottom", height = 38, exclusive_zone = 38, content = "lib.bar",
      }
      whirlpool.surface("bar", {
        provider = "river", role = "shell", placement = "all-outputs",
        edge = bar.edge, height = bar.height, exclusive_zone = bar.exclusive_zone, content = bar.content,
      })
      whirlpool.surface("bar-portable", {
        provider = "layer-shell", role = "shell", placement = "default-output",
        edge = bar.edge, height = bar.height, exclusive_zone = bar.exclusive_zone, content = bar.content,
      })
      -- The volume popup, near the top of each output.
      whirlpool.surface("osd", {
        provider = "river", role = "shell", placement = "all-outputs",
        edge = "top", margin = 80, width = 320, height = 120, input = false,
        content = "lib.osd",
      })
      whirlpool.surface("titles", {
        provider = "river", role = "decoration", placement = "windows",
        edge = "top", height = 28, content = "lib.decorator",
      })
      -- Where a dragged window will land: drawn on the layout's `drop` mark; and
      -- along an edge where holding it moves it to the next row, its `shift` mark.
      whirlpool.surface("drop", {
        provider = "river", role = "shell", placement = "mark", mark = "drop",
        content = "lib.drop",
      })
      whirlpool.surface("shift", {
        provider = "river", role = "shell", placement = "mark", mark = "shift",
        content = "lib.drop",
      })
    '';

    # Whirlpool finds modules beside the configuration, so the generated file
    # sits next to the example configuration's `lib/`.
    configDir = pkgs.linkFarm "whirlpool-config" [
      { name = "whirlpool.lua"; path = luaConfig; }
      { name = "lib"; path = "${package.config}/lib"; }
    ];
  in {
    home.packages = [
      pkgs.grim
      pkgs.slurp
      pkgs.libnotify
      pkgs.wl-clipboard
      pkgs.playerctl
      screenshot-menu
      sign-clipboard
      power-menu
    ];

    psyclyx.home.programs.fuzzel.enable = lib.mkDefault true;

    services.whirlpool = {
      enable = true;
      package = package;
      configFile = "${configDir}/whirlpool.lua";
    };
  };
}
