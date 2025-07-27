{ config, lib, ... }:
let
  cfg = config.psyclyx.programs.waybar;
in
{
  imports = [ ./style.nix ];

  options = {
    psyclyx = {
      programs = {
        waybar = {
          enable = lib.mkEnableOption "Enable Waybar";
          cores = lib.mkOption {
            type = lib.types.ints.positive;
            description = "CPU core count";
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs = {
      waybar = {
        enable = true;
        settings = {
          mainBar = {
            layer = "bottom";
            position = "top";
            spacing = 16;
            height = 32;
            margin = "0px 0px";
            padding = "0px 0px";
            modules-left = [
              "sway/workspaces"
              "sway/scratchpad"
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
            "sway/workspaces" = {
              on-click = "activate";
              sort-by-number = true;
            };
            "sway/scratchpad" = {
              format-icons = [
                ""
                "[scratch]"
              ];
            };
            "pulseaudio" = {
              format = "VOL: {volume}%";
              format-muted = "VOL: MUTE";
            };

            "network" =
              let
                format_speed = "{bandwidthDownBytes} / {bandwidthUpBytes}";
              in
              {
                format-wifi = "WIFI: {signalStrength}% ${format_speed}";
                tooltip = "{essid} {ifname} {ipaddr}/{cidr}";
                format-ethernet = "ETH: ${format_speed}";
                format-linked = "NET: {ifname} (No IP) ${format_speed}";
                format-disconnected = "NET: NONE";
                interval = 3;
              };

            "backlight" = {
              format = "BLT: {percent}%";
              format-icons = [
                "󰹐"
                "󱩎"
                "󱩏"
                "󱩐"
                "󱩑"
                "󱩒"
                "󱩓"
                "󱩔"
                "󱩕"
                "󱩖"
                "󰛨"
              ];
            };
            "clock" = {
              interval = 15;
              tooltip = false;
              format = "{:%I:%M %m/%d/%y}";
            };
            "cpu" = {
              interval = 4;
              format = "CPU: {}%";
            };
            "memory" = {
              interval = 4;
              format = "MEM: {}%";
            };
            "battery" = {
              interval = 4;
              format = "BAT: {capacity}%";
            };
          };
        };
      };
    };
  };
}
