{
  path = ["psyclyx" "home" "programs" "whirlpool"];
  description = "Whirlpool window manager and shell configuration";
  options = {lib, ...}: {
    bar = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      example = {
        primary = ["BNQ BenQ RD280U"];
        segments = ["cpu" "memory" "network" "audio" "notifications" "clock"];
        network = {
          on = "primary";
          elsewhere = "minimal";
        };
        disks.on = ["Dell Inc. DELL S2721QS"];
      };
      description = ''
        Options for Whirlpool's bar, laid over this module's defaults and
        passed to it as they are (see lib/bar/options.lua in Whirlpool's
        example configuration): which status segments there are and in what
        order (`segments`), each one's own table (its priority when room
        runs out, and `on` / `elsewhere` for which monitors show it and how
        fully), and `primary`, the monitor that is the primary one (patterns
        as in psyclyx.home.hardware.monitors identifiers; unset, the
        widest, leftmost).

        With more than one monitor declared, the default keeps detail on the
        primary and a little of it on the others. Whatever is asked, with a
        single monitor connected everything is on it, as small as it needs
        to be.
      '';
    };
  };
  config = {
    cfg,
    config,
    lib,
    pkgs,
    ...
  }: let
    package = pkgs.psyclyx.whirlpool;

    # The bar: one height for the surfaces and the program. On a desk with
    # several monitors the same panels on each are noise: the primary one has
    # everything, the others the time, sound, notifications and a glance at
    # the machine. Whirlpool resolves this against the monitors connected, so
    # a lone (or small) one still shows all of it, compacted to fit.
    monitors = lib.filterAttrs (_: m: m.enable) config.psyclyx.home.hardware.monitors;
    barSpread = lib.optionalAttrs (lib.length (lib.attrNames monitors) > 1) {
      cpu = {
        on = "primary";
        elsewhere = "minimal";
      };
      memory = {
        on = "primary";
        elsewhere = "minimal";
      };
      network = {
        on = "primary";
        elsewhere = "minimal";
      };
      gpu.on = "primary";
      disks.on = "primary";
      tray.on = "primary";
    };
    # The declared primary monitor, if any (else Whirlpool picks the widest,
    # leftmost).
    primaryMonitors = lib.mapAttrsToList (_: m: m.identifier) (lib.filterAttrs (_: m: m.primary) monitors);
    barPrimary = lib.optionalAttrs (primaryMonitors != []) {primary = primaryMonitors;};
    barOptions = lib.recursiveUpdate ({height = 38;} // barSpread // barPrimary) cfg.bar;

    # Whirlpool's own menu, for scripts (`whirlpool dmenu` reads items on
    # stdin and prints the choice, as dmenu does; typed text that matches
    # nothing is accepted too).
    dmenu = "${lib.getExe package} dmenu";
    rofi-rbw = lib.getExe pkgs.rofi-rbw-wayland;
    grim = lib.getExe pkgs.grim;
    notify-send = lib.getExe' pkgs.libnotify "notify-send";
    slurp = lib.getExe pkgs.slurp;
    wl-copy = lib.getExe' pkgs.wl-clipboard "wl-copy";

    wl-paste = lib.getExe' pkgs.wl-clipboard "wl-paste";
    ssh-keygen = "${pkgs.openssh}/bin/ssh-keygen";

    # The rofi/fuzzel/dmenu shims (Whirlpool menus under those names) stand in
    # for the real tools; they cannot share PATH with a real fuzzel, so they
    # stay off where another session (sway) installs it.
    compat = !(config.programs.fuzzel.enable or false);

    # Lua string-literal quoting for values interpolated into the generated
    # config below (paths only — no user-controlled input reaches this).
    luaStr = s: ''"${s}"'';
    spawnAction = args: ''action("spawn", ${lib.concatMapStringsSep ", " luaStr args})'';
    # Whirlpool's spawn is a direct fork of the whirlpool process, so anything
    # it launches lands in the whirlpool.service cgroup (logs attributed to
    # whirlpool, killed on whirlpool restart). Route GUI apps through
    # `uwsm app --` so they get their own app-*.scope under app.slice.
    # One-shot utilities (playerctl) stay bare.
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
      key=$(echo "$keys" | ${dmenu} -p "Key: ") || exit 0

      # 3. Pick namespace (recent first, then type custom)
      recent=$(tac "$ns_history" | awk '!seen[$0]++' | head -10)
      ns=$(echo "$recent" | ${dmenu} -p "Namespace: ") || exit 0
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

    # Ported from the retired Tidepool/Shoal config. Tidepool's
    # toggle-focus-float, gather-floats, the pointer-drag-to-float binding,
    # and the outer-padding/peek-width layout tuning have no equivalent in
    # Whirlpool's scrolling layout yet — dropped rather than approximated.
    # Per-output tag pinning (Tidepool's outputOrder) is also dropped for
    # now; Whirlpool has no equivalent concept yet.
    #
    # Every key is listed, with its chord, in the Commands menu (Super+X);
    # menus and context menus show the chord of a key that does what an item
    # does. The layout's keys name a verb of Whirlpool's lib/objects.lua
    # (`object`, `verb`) and take its words; the others say theirs (`desc`).
    luaConfig = pkgs.writeText "whirlpool.lua" ''
      local whirlpool = require("whirlpool")
      local function action(name, ...)
        return { name = name, args = { ... } }
      end
      local function layout(name, ...)
        return action("layout", name, ...)
      end
      local Actions = require("whirlpool.actions")
      local Objects = require("lib.objects")
      -- What the layout's keys act on: the focused window (to the layout,
      -- the selection: Super+G widens it to the group around it, then its
      -- row), the group it is in (or its row), its size, focus and the view.
      local window, group, size, view = Objects.focused(), Objects.group("focused"), Objects.size(), Objects.view()

      local super = { "super" }
      local super_shift = { "super", "shift" }
      local super_ctrl = { "super", "ctrl" }
      local super_ctrl_shift = { "super", "ctrl", "shift" }
      local super_alt = { "super", "alt" }
      local super_alt_shift = { "super", "alt", "shift" }

      local bindings = {
        { modifiers = super, key = "Return", action = ${appSpawn ["xdg-terminal-exec"]}, desc = "Terminal" },
        { modifiers = super_shift, key = "q", object = window, verb = "close" },

        -- Directional focus
        { modifiers = super, key = "h", object = view, verb = "focus-left" },
        { modifiers = super, key = "l", object = view, verb = "focus-right" },
        { modifiers = super, key = "j", object = view, verb = "focus-down" },
        { modifiers = super, key = "k", object = view, verb = "focus-up" },

        -- The verbs (whirlpool docs/design/layout-v3.md §2), each on the
        -- selection: the focused window, or with Super+G the group around
        -- it, then its row.
        -- Move: one place that way. Past the sibling there (a swap); where
        -- there is none that way, out of its group that way: the middle of
        -- a stack, moved right, becomes a column to the stack's right.
        { modifiers = super_shift, key = "h", object = window, verb = "move-left" },
        { modifiers = super_shift, key = "l", object = window, verb = "move-right" },
        { modifiers = super_shift, key = "j", object = window, verb = "move-down" },
        { modifiers = super_shift, key = "k", object = window, verb = "move-up" },

        -- Join: go and stay with what is that way (into the group there, or
        -- the two become a stack). Leave: out to a column of its own. Group:
        -- a new named group around it, nothing rearranged.
        { modifiers = super_ctrl, key = "h", object = window, verb = "join-left" },
        { modifiers = super_ctrl, key = "l", object = window, verb = "join-right" },
        { modifiers = super_ctrl, key = "j", object = window, verb = "join-down" },
        { modifiers = super_ctrl, key = "k", object = window, verb = "join-up" },
        { modifiers = super_ctrl, key = "space", object = window, verb = "leave" },
        { modifiers = super_ctrl, key = "Return", object = window, verb = "group" },
        { modifiers = super, key = "g", object = view, verb = "select-parent" },
        { modifiers = super_shift, key = "g", object = view, verb = "select-child" },

        -- Arrangements: of the group the window is in, else of its row
        -- (scrolling, fit the screen, main and stack, grid, spiral; a group
        -- also stack, columns, tabs). Super+Shift+A lists them. Turning is
        -- apart: a row turns the tag, a group moves its main window round.
        { modifiers = super, key = "space", object = group, verb = "layout" },
        { modifiers = super_shift, key = "space", object = group, verb = "layout-prev" },
        { modifiers = super_alt, key = "space", object = group, verb = "turn" },

        -- Width presets, tabs, and outputs
        { modifiers = super, key = "r", object = size, verb = "next" },
        { modifiers = super, key = "Tab", object = view, verb = "tab-next" },
        { modifiers = super_shift, key = "Tab", object = view, verb = "tab-prev" },
        { modifiers = super, key = "comma", object = view, verb = "output-prev" },
        { modifiers = super, key = "period", object = view, verb = "output-next" },

        -- Tags
        { modifiers = super, key = "1", object = Objects.tag(1), verb = "focus" },
        { modifiers = super, key = "2", object = Objects.tag(2), verb = "focus" },
        { modifiers = super, key = "3", object = Objects.tag(3), verb = "focus" },
        { modifiers = super, key = "4", object = Objects.tag(4), verb = "focus" },
        { modifiers = super, key = "5", object = Objects.tag(5), verb = "focus" },
        { modifiers = super_shift, key = "1", object = Objects.tag(1), verb = "send" },
        { modifiers = super_shift, key = "2", object = Objects.tag(2), verb = "send" },
        { modifiers = super_shift, key = "3", object = Objects.tag(3), verb = "send" },
        { modifiers = super_shift, key = "4", object = Objects.tag(4), verb = "send" },
        { modifiers = super_shift, key = "5", object = Objects.tag(5), verb = "send" },

        -- Fullscreen and floating windows
        { modifiers = super, key = "slash", object = window, verb = "fullscreen" },
        -- Put away (still listed: focusing it from the windows menu or the
        -- bar brings it back where it was).
        { modifiers = super, key = "minus", object = window, verb = "minimize" },
        -- Open like this: remember how this window is (width, floating, its
        -- named group) for new windows of its application; again forgets.
        -- Super+Ctrl+Shift+S lists what is remembered.
        { modifiers = super_ctrl, key = "s", object = window, verb = "remember" },

        -- The view: a window (or a row) that way, held until focus moves;
        -- Super+C, or Super+right-click, brings it back to the focused window.
        { modifiers = super, key = "Left", object = view, verb = "pan-left" },
        { modifiers = super, key = "Right", object = view, verb = "pan-right" },
        { modifiers = super, key = "Up", object = view, verb = "pan-up" },
        { modifiers = super, key = "Down", object = view, verb = "pan-down" },
        { modifiers = super, key = "c", object = view, verb = "recenter" },
        { modifiers = super, key = "pointer:right", object = view, verb = "recenter" },
        -- Super+drag moves a window from anywhere on it (the selected group,
        -- if it is in it); with Shift, its group. Super+middle-drag grabs
        -- the view: the row under the pointer along itself, or the rows
        -- across, whichever way the drag first goes; with Shift, the whole
        -- view both ways. It coasts if let go moving, as does scrolling over
        -- a title bar. None of it moves focus.
        { modifiers = super, key = "pointer:left", action = action("pointer-operation", "drag-window") },
        { modifiers = super_shift, key = "pointer:left", action = action("pointer-operation", "drag-group") },
        { modifiers = super, key = "pointer:middle", action = action("pointer-operation", "pan-view") },
        { modifiers = super_shift, key = "pointer:middle", action = action("pointer-operation", "pan-view", "view") },
        { modifiers = super, key = "f", object = window, verb = "float" },
        { modifiers = super_shift, key = "f", object = window, verb = "float" },

        -- Resize. Width is along the rows, height across them; a window in a
        -- stack is sized by its share of it, otherwise by its column (width)
        -- or its row (height). One preset per step; the bar shows the size.
        { modifiers = super_alt, key = "h", object = size, verb = "narrower" },
        { modifiers = super_alt, key = "l", object = size, verb = "wider" },
        { modifiers = super_alt, key = "k", object = size, verb = "shorter" },
        { modifiers = super_alt, key = "j", object = size, verb = "taller" },
        { modifiers = super_shift, key = "r", object = size, verb = "previous" },
        { modifiers = super_alt, key = "r", object = size, verb = "next-height" },
        { modifiers = super_alt_shift, key = "r", object = size, verb = "previous-height" },
        { modifiers = super_alt, key = "equal", object = size, verb = "even" },
        { modifiers = super_alt, key = "0", object = size, verb = "reset" },

        -- One-shot mark prefixes. The following unmodified letter is
        -- captured only while the corresponding mode is active. A mark set
        -- on what it already points at clears it; Super+' ' (the jump's key
        -- twice) goes back to the window focused before; Return in the
        -- clearing mode clears every mark on the selection.
        { modifiers = super, key = "m", action = action("enter-mode", "mark") },
        { modifiers = super, key = "'", action = action("enter-mode", "focus-mark") },
        { modifiers = super_shift, key = "m", action = action("enter-mode", "summon-mark") },
        { modifiers = super_ctrl, key = "m", action = action("enter-mode", "send-to-mark") },
        { modifiers = super_ctrl_shift, key = "m", action = action("enter-mode", "clear-mark") },

        -- Players. The volume keys are the shell's (below): through the
        -- sound service, so the level stays in bounds and the on-screen
        -- display shows it. `locked`: they work on the lock screen too, where
        -- no other binding does.
        { key = "XF86AudioPlay", action = action("spawn", "playerctl", "play-pause"), desc = "Play or pause", locked = true },
        { key = "XF86AudioNext", action = action("spawn", "playerctl", "next"), desc = "Next track", locked = true },
        { key = "XF86AudioPrev", action = action("spawn", "playerctl", "previous"), desc = "Previous track", locked = true },
        { key = "XF86AudioStop", action = action("spawn", "playerctl", "stop"), desc = "Stop playing", locked = true },

        -- Named groups and tabs. Super+Ctrl+G (name the focused group: a bare
        -- window names its row) is the shell's naming prompt, below.
        { modifiers = super_ctrl_shift, key = "g", object = group, verb = "unname" },
        { modifiers = super_alt, key = "g", object = group, verb = "hue" },
        { modifiers = super, key = "]", object = view, verb = "group-next" },
        { modifiers = super, key = "[", object = view, verb = "group-prev" },
        { modifiers = super, key = "t", object = window, verb = "tabs" },
        { modifiers = super_shift, key = "t", object = window, verb = "tabs" },
        { modifiers = super_shift, key = "[", object = window, verb = "tab-left" },
        { modifiers = super_shift, key = "]", object = window, verb = "tab-right" },

        -- Launchers. Super+D (run), Super+S (screenshot) and Super+Shift+E
        -- (power) are the shell's menus, below.
        { modifiers = super, key = "p", action = ${appSpawn [rofi-rbw]}, desc = "Passwords" },
        { modifiers = super_shift, key = "s", action = ${appSpawn [(lib.getExe sign-clipboard)]}, desc = "Sign the clipboard" },
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
      bindings[#bindings + 1] = { mode = "focus-mark", key = "'", action = layout("focus-last") }
      bindings[#bindings + 1] = { mode = "clear-mark", key = "Return", action = layout("clear-mark") }

      for _, binding in ipairs(bindings) do
        local options = { mode = binding.mode, desc = binding.desc, locked = binding.locked }
        if binding.verb then
          assert(Actions.bind(binding.modifiers or {}, binding.key, binding.object, binding.verb, options),
            "no verb " .. binding.verb .. " on " .. binding.object.address)
        else
          whirlpool.bind(binding.modifiers or {}, binding.key, binding.action, options)
        end
      end

      -- `lib.*` is Whirlpool's example library, linked beside this file.
      -- Borders in the theme's colours; named groups keep a margin round
      -- them for their frame and a lane above for their name. `peek` (how
      -- much of the windows beyond the page shows at its ends, in pixels;
      -- a title bar's height unless set, 0 for none) and `default_width`
      -- are the tuning there is.
      whirlpool.layout("lib.scrolling", {
        widths = { 0.25, 1 / 3, 0.5, 2 / 3, 0.75, 1 },
        palette = require("lib.scrolling.palette")(),
        motion = require("lib.theme").motion,
        lanes = true,
      })

      -- Every source lib.bar draws from (temperatures, GPU, ...).
      require("lib.sources").register()

      -- The bar's options (psyclyx.home.programs.whirlpool.bar): its status
      -- segments, and which monitors show which.
      local bar_options = ${lib.generators.toLua {} barOptions}
      local bar = {
        edge = "bottom", height = bar_options.height, exclusive_zone = bar_options.height,
        content = "lib.bar", options = bar_options,
      }
      whirlpool.surface("bar", {
        provider = "river", role = "shell", placement = "all-outputs",
        edge = bar.edge, height = bar.height, exclusive_zone = bar.exclusive_zone,
        content = bar.content, options = bar.options,
      })
      whirlpool.surface("bar-portable", {
        provider = "layer-shell", role = "shell", placement = "default-output",
        edge = bar.edge, height = bar.height, exclusive_zone = bar.exclusive_zone,
        content = bar.content, options = bar.options,
      })
      whirlpool.surface("titles", {
        provider = "river", role = "decoration", placement = "windows",
        -- The title bars' height: the layout keeps this much above each window
        -- (their type, icons and buttons follow it).
        edge = "top", height = 36, content = "lib.decorator",
        -- The buttons at a title bar's right end, left to right: any of
        -- "minimize", "float", "fullscreen", "close" ({} for none). Every one
        -- is also in the bar's right-click menu and bound to keys.
        options = { buttons = { "minimize", "fullscreen", "close" } },
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
      -- Named groups: each one's frame and name, and named rows' names, on
      -- one surface under the windows (the layout's `groups` mark).
      whirlpool.surface("groups", {
        provider = "river", role = "shell", placement = "mark", mark = "groups",
        content = "lib.groupframe",
      })
      -- (The layout before layout-v3 marked each name on its own; harmless
      -- after it, and can go once that is what is installed.)
      whirlpool.surface("group-label", {
        provider = "river", role = "shell", placement = "mark", mark = "group-label",
        content = "lib.grouplabel",
      })
      -- Windows peeking in from beyond the page: a scrim over one further
      -- along the row, a title-bar-shaped tab for one of another row; a
      -- click focuses it. One surface per output draws them all (`pool`): a
      -- peek changes size as the view moves, and only a pooled surface is
      -- told the windows' titles and icons.
      whirlpool.surface("peek", {
        provider = "river", role = "shell", placement = "mark", mark = "peek", pool = true,
        content = "lib.peek",
      })
      -- What a pan by pointer is moving: rails along the way it slides.
      whirlpool.surface("pan", {
        provider = "river", role = "shell", placement = "mark", mark = "pan",
        content = "lib.pan",
      })
      -- For a moment after an arrangement changes (Super+Space and the
      -- rest): a card over the row or group naming it, with a schematic.
      whirlpool.surface("arrangement", {
        provider = "river", role = "shell", placement = "mark", mark = "arrangement",
        content = "lib.arrangement",
      })
      -- The lock screen (`whirlpool lock`, services.whirlpool.lock below):
      -- drawn on every output while the session is locked.
      whirlpool.surface("lock", {
        provider = "session-lock", role = "lock", placement = "all-outputs",
        content = "lib.lock",
      })
      -- polkit's password prompt (`whirlpool polkit-agent`, services.whirlpool
      -- .polkitAgent below): over the focused output while asked.
      whirlpool.surface("polkit", {
        provider = "polkit-agent", role = "prompt", placement = "overlay",
        content = "lib.polkit",
      })

      -- The shell (lib/shell.lua): menus (Super+; everything at once,
      -- Super+D run, Super+W windows, Super+Shift+W named groups, Super+X
      -- commands, Super+Ctrl+G name a group; Super+S screenshot and Super+Shift+E power as single-key
      -- menus), notifications by the bar's bell (Super+N the centre,
      -- Super+Shift+N dismiss, Super+Ctrl+N open), the tray, the sound panel
      -- (Super+A; the bar's readouts open the network, Wi-Fi and disks
      -- panels), the overview (Super+O; again: every tag, on every monitor),
      -- the volume and brightness keys with
      -- their on-screen display, and Super+Escape to close any panel. The
      -- status popover (a bar segment shown small, or the bar's "more"
      -- button) draws the bar's segments, so it is given the bar's options.
      require("lib.shell").setup({
        status = bar_options,
        wrap = { "uwsm", "app", "--" },
        tools = {
          grim = "${grim}", slurp = "${slurp}", wl_copy = "${wl-copy}", notify = "${notify-send}",
          loginctl = "${pkgs.systemd}/bin/loginctl", systemctl = "${pkgs.systemd}/bin/systemctl",
        },
        commands = {
          lock = { "${lib.getExe config.services.whirlpool.lock.package}" },
          logout = { "${lib.getExe pkgs.wayland-logout}" },
        },
        notifications = { corner = "bottom-right" },
        keys = { omnibox = { super, "semicolon" } },
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
      sign-clipboard
    ];

    # rofi-rbw picks through the rofi shim (custom keys and -mesg are what
    # it needs), and rbw asks for the master password in a Whirlpool menu:
    # the prompt is a panel, so focus never leaves the window it came from.
    xdg.configFile."rofi-rbw.rc".text = lib.mkIf compat (lib.mkForce "selector=rofi");
    psyclyx.home.programs.rbw.pinentry = lib.mkDefault config.services.whirlpool.pinentry.package;

    services.whirlpool = {
      enable = true;
      package = package;
      configFile = "${configDir}/whirlpool.lua";
      # rofi/fuzzel/dmenu shims in place of fuzzel, the pinentry, and the
      # built-in notification server in place of mako.
      compat.enable = compat;
      pinentry.enable = true;
      notifications.enable = true;
      # Whirlpool's own lock screen, in place of swaylock (still installed by
      # programs/river.nix, unused, as a fallback): the power menu's Lock,
      # `loginctl lock-session`, and before sleep. As swaylock-effects was:
      # a pixelated screenshot, 8 px blocks, 3 s grace. Needs the NixOS PAM
      # service `whirlpool-lock` (nixos/programs/river.nix).
      lock = {
        enable = true;
        grace = 3;
        background = "screenshot";
        effect = "pixelate";
        effectSize = 8;
      };
      # The session's polkit agent: a Whirlpool prompt when an application
      # asks polkit for something that needs a password (networkd's link
      # actions from the bar, say). The only agent: nothing else here starts
      # one (no polkit-gnome, lxqt-policykit, hyprpolkitagent).
      polkitAgent.enable = true;
    };
  };
}
