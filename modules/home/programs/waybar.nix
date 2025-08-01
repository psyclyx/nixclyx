{ config, lib, ... }:
let
  cfg = config.psyclyx.programs.waybar;
  opacity = "${config.stylix.opacity.desktop}";
in
{
  options.psyclyx.programs.waybar.enable = lib.mkEnableOption "waybar config";

  config = lib.mkIf cfg.enable {
    stylix.targets.waybar.addCss = false;
    programs.waybar = {
      enable = true;
      style =
        lib.mkAfter # css
          ''
            * {
                border: none;
                border-radius: 0;
            }

            window#waybar {
                background: alpha(@base01, ${opacity});
                color: @base04;
            }

            tooltip {
                background-color: alpha(@base01, ${opacity});
            }

            tooltip label {
                color: @base04;
            }

            #workspaces button {
                color: @base04;
                background: transparent;
            }

            #workspaces button.focused {
                background: @base00;
                color: @base05;
            }

            #workspaces button.urgent {
                background: @base02;
                color: @base05;
            }

            #clock,
            #network,
            #backlight,
            #pulseaudio,
            #memory,
            #cpu,
            #battery {
                color: @base05;
                padding: 0 8px;
            }
          '';
      settings = {
        mainBar = {
          position = "top";
          height = 24;
          spacing = 16;

          modules-left = [
            "sway/workspaces"
            "sway/mode"
          ];
          modules-center = [
            "clock"
          ];
          modules-right = [
            "network"
            "backlight"
            "pulseaudio"
            "memory"
            "cpu"
            "battery"
          ];

          "pulseaudio" = {
            format = "VOL: {volume}%";
            format-muted = "VOL: MUTE";
          };
          "network" = {
            format-wifi = "WIFI: {ifname} {ipaddr}/{cidr} {signalStrength}%";
            format-ethernet = "ETH: {ifname} {ipaddr/cider}";
            format-linked = "NET: {ifname} (No IP)";
            format-disconnected = "NET: NONE";
            interval = 10;
          };
          "backlight" = {
            format = "BLT: {percent}%";
          };
          "clock" = {
            interval = 5;
            format = "{:%I:%M %m/%d/%y}";
          };
          "cpu" = {
            interval = 5;
            format = "CPU: {}%";
          };
          "memory" = {
            interval = 5;
            format = "MEM: {}%";
          };
          "battery" = {
            interval = 5;
            format = "BAT: {capacity}%";
          };
        };
      };
    };
  };
}
