{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.home.programs.niri;
  monitors = config.psyclyx.home.hardware.monitors;

  toNiriOutput = monitor: {
    ${monitor.connector} = lib.filterAttrs (_: v: v != null) (
      {
        position = {
          x = monitor.position.x;
          y = monitor.position.y;
        };
        scale = monitor.scale;
        enable = monitor.enable;
      }
      // lib.optionalAttrs (monitor.mode != null) {
        mode = let
          m = monitor.mode;
        in
          {
            width = m.width;
            height = m.height;
          }
          // lib.optionalAttrs (m.refresh != null) {refresh = m.refresh;};
      }
    );
  };

  monitorOutputs = lib.foldl' (acc: m: acc // toNiriOutput m) {} (lib.attrValues monitors);
in {
  options = {
    psyclyx.home.programs.niri = {
      enable = lib.mkEnableOption "Niri config";
      binds = {
        modifiers = {
          leader = lib.mkOption {
            type = lib.types.str;
            default = "Mod";
            description = "Modifier prefix for window management bindings.";
          };
          move = lib.mkOption {
            type = lib.types.str;
            default = "Shift";
            description = "Modifier held to move something.";
          };
        };

        movement =
          lib.mapAttrs
          (
            dir: default:
              lib.mkOption {
                type = lib.types.str;
                inherit default;
                description = "Key to move focus ${dir}.";
              }
          )
          {
            left = "h";
            down = "j";
            up = "k";
            right = "l";
          };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.niri = {
      settings = {
        outputs = lib.mkIf (monitors != {}) monitorOutputs;
        binds = let
          inherit (cfg.binds) modifiers movement;
          prefixBind = prefix: bind: args: {
            name = "${prefix}+${bind}";
            value = args;
          };
        in
          lib.mapAttrs' (prefixBind modifiers.leader) {
            "Return".action.spawn = lib.getExe config.programs.fuzzel.package;
            "Q".action.close-window = {};
            "Shift+E".action.quit = {};

            "${movement.left}".action.focus-column-left = {};
            "${movement.down}".action.focus-window-or-workspace-down = {};
            "${movement.up}".action.focus-window-or-workspace-up = {};
            "${movement.right}".action.focus-column-right = {};

            "${modifiers.move}+${movement.left}".action.move-column-left = {};
            "${modifiers.move}+${movement.down}".action.move-window-down-or-to-workspace-down = {};
            "${modifiers.move}+${movement.up}".action.move-window-up-or-to-workspace-up = {};
            "${modifiers.move}+${movement.right}".action.move-column-right = {};

            "N".action.focus-workspace-down = {};
            "P".action.focus-workspace-up = {};
            "${modifiers.move}+N".action.move-column-to-workspace-down = {};
            "${modifiers.move}+P".action.move-column-to-workspace-up = {};

            "1".action.focus-workspace = 1;
            "2".action.focus-workspace = 2;
            "3".action.focus-workspace = 3;
            "4".action.focus-workspace = 4;
            "5".action.focus-workspace = 5;
            "6".action.focus-workspace = 6;
            "7".action.focus-workspace = 7;
            "8".action.focus-workspace = 8;
            "9".action.focus-workspace = 9;

            "${modifiers.move}+1".action.move-column-to-workspace = 1;
            "${modifiers.move}+2".action.move-column-to-workspace = 2;
            "${modifiers.move}+3".action.move-column-to-workspace = 3;
            "${modifiers.move}+4".action.move-column-to-workspace = 4;
            "${modifiers.move}+5".action.move-column-to-workspace = 5;
            "${modifiers.move}+6".action.move-column-to-workspace = 6;
            "${modifiers.move}+7".action.move-column-to-workspace = 7;
            "${modifiers.move}+8".action.move-column-to-workspace = 8;
            "${modifiers.move}+9".action.move-column-to-workspace = 9;

            "Minus".action.set-column-width = "-10%";
            "Equal".action.set-column-width = "+10%";
            "Shift+Minus".action.set-window-height = "-10%";
            "Shift+Equal".action.set-window-height = "+10%";

            "R".action.switch-preset-column-width = {};
            "F".action.maximize-column = {};
            "Shift+F".action.fullscreen-window = {};

            "Escape".action.toggle-keyboard-shortcuts-inhibit = {};

            "WheelScrollDown" = {
              action.focus-workspace-down = {};
              cooldown-ms = 150;
            };

            "WheelScrollUp" = {
              action.focus-workspace-up = {};
              cooldown-ms = 150;
            };
          };
      };
    };
  };
}
