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

    waybarConfig = pkgs.writeText "waybar-river.json" (builtins.toJSON {
      spacing = 16;
      modules-left = ["river/tags" "river/mode"];
      modules-center = ["clock"];
      modules-right = ["network" "backlight" "pulseaudio" "memory" "cpu" "battery" "tray"];
      "river/tags" = {num-tags = 10;};
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
    });

    waybarCss = pkgs.writeText "waybar-river.css" ''
      * {
          border: none;
          border-radius: 0;
      }
      window#waybar {
          background: alpha(@base01, ${opacity});
          color: @base04;
          padding: 0;
          margin: 0;
      }
      tooltip {
          background-color: alpha(@base01, ${opacity});
      }
      tooltip label {
          color: @base05;
      }
      #tags button {
          color: @base04;
          background: transparent;
      }
      #tags button.focused {
          background: @base00;
          color: @base05;
      }
      #tags button.occupied {
          color: @base05;
      }
      #tags button.urgent {
          background: @base02;
          color: @base05;
      }
      #mode {
          color: @base05;
          padding: 0 8px;
      }
      #clock,
      #network,
      #backlight,
      #pulseaudio,
      #memory,
      #cpu,
      #battery,
      #tray {
          color: @base05;
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

    initScript = pkgs.writeShellScript "river-init" ''
      riverctl background-color 0x${c.base00}
      riverctl border-color-focused 0x${c.base07}
      riverctl border-color-unfocused 0x${c.base03}
      riverctl border-color-urgent 0x${c.base08}
      riverctl border-width 4

      riverctl set-repeat 50 300
      riverctl default-layout rivertile
      riverctl focus-follows-cursor normal

      riverctl map -repeat normal Super J focus-view next
      riverctl map -repeat normal Super K focus-view previous
      riverctl map normal Super+Shift J swap next
      riverctl map normal Super+Shift K swap previous

      riverctl map -repeat normal Super H send-layout-cmd rivertile "main-ratio -0.05"
      riverctl map -repeat normal Super L send-layout-cmd rivertile "main-ratio +0.05"
      riverctl map normal Super+Shift H send-layout-cmd rivertile "main-count +1"
      riverctl map normal Super+Shift L send-layout-cmd rivertile "main-count -1"

      for i in $(seq 1 9); do
          tags=$((1 << (i - 1)))
          riverctl map normal Super "$i" set-focused-tags $tags
          riverctl map normal Super+Shift "$i" set-view-tags $tags
          riverctl map normal Super+Control "$i" toggle-focused-tags $tags
          riverctl map normal Super+Control+Shift "$i" toggle-view-tags $tags
      done
      tags=$((1 << 9))
      riverctl map normal Super 0 set-focused-tags $tags
      riverctl map normal Super+Shift 0 set-view-tags $tags
      riverctl map normal Super+Control 0 toggle-focused-tags $tags
      riverctl map normal Super+Control+Shift 0 toggle-view-tags $tags

      all_tags=$(((1 << 32) - 1))
      riverctl map normal Super A set-focused-tags $all_tags
      riverctl map normal Super+Shift A set-view-tags $all_tags

      riverctl map normal Super Semicolon toggle-float
      riverctl map normal Super Slash toggle-fullscreen

      riverctl map normal Super Period focus-output next
      riverctl map normal Super Comma focus-output previous
      riverctl map normal Super+Shift Period send-to-output next
      riverctl map normal Super+Shift Comma send-to-output previous

      riverctl map normal Super Return spawn "uwsm app -- ${fuzzel}"
      riverctl map normal Super I spawn "uwsm app -- xdg-terminal-exec"
      riverctl map normal Super U spawn "uwsm app -- firefox"
      riverctl map normal Super X spawn "uwsm app -- ${lib.getExe power-menu}"
      riverctl map normal Super S spawn "uwsm app -- ${lib.getExe screenshot-menu}"

      riverctl map normal Super+Shift Q close
      riverctl map normal Super+Shift E exit

      riverctl declare-mode resize
      riverctl map normal Super R enter-mode resize
      riverctl map resize None Escape enter-mode normal
      riverctl map -repeat resize None H send-layout-cmd rivertile "main-ratio -0.05"
      riverctl map -repeat resize None L send-layout-cmd rivertile "main-ratio +0.05"
      riverctl map resize None K send-layout-cmd rivertile "main-count +1"
      riverctl map resize None J send-layout-cmd rivertile "main-count -1"

      for mode in normal locked; do
          riverctl map -repeat $mode None XF86AudioRaiseVolume spawn "pactl set-sink-volume @DEFAULT_SINK@ +5%"
          riverctl map -repeat $mode None XF86AudioLowerVolume spawn "pactl set-sink-volume @DEFAULT_SINK@ -5%"
          riverctl map $mode None XF86AudioMute spawn "pactl set-sink-mute @DEFAULT_SINK@ toggle"
          riverctl map -repeat $mode None XF86MonBrightnessUp spawn "light -A 10"
          riverctl map -repeat $mode None XF86MonBrightnessDown spawn "light -U 10"
      done

      riverctl map-pointer normal Super BTN_LEFT move-view
      riverctl map-pointer normal Super BTN_RIGHT resize-view

      riverctl rule-add -app-id "xdg-desktop-portal-gtk" float
      riverctl rule-add -app-id "firefox" -title "Library" float

      ${outputSetup}

      rivertile -view-padding 8 -outer-padding 4 &
      uwsm app -- waybar -c ${waybarConfig} -s ${waybarCss} &

      uwsm finalize
    '';
  in {
    home.packages = [
      pkgs.pulseaudio
      pkgs.grim
      pkgs.slurp
      pkgs.libnotify
      pkgs.wayland-logout
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
  };
}
