{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.psyclyx.services.sketchybar;

  padHex = s: if lib.stringLength s == 1 then "0${s}" else s;
  mkThemeEnv =
    colors:
    lib.listToAttrs (
      lib.lists.imap0 (i: rgb: {
        name = "BASE${padHex (builtins.toString i)}";
        value = "#FF${rgb}";
      }) colors
    );
  themeEnv = lib.debug.traceVal mkThemeEnv config.lib.stylix.colors.toList;

  aerospacePlugin = pkgs.writeShellApplication rec {
    name = "aerospace_plugin";
    text = builtins.readFile ./aerospace_plugin.sh;
    derivationArgs.buildInputs = with pkgs; [
      aerospace
      sketchybar
    ];
    runtimeInputs = derivationArgs.buildInputs;
  };

  appNamePlugin = pkgs.writeShellApplication rec {
    name = "app_name_plugin";
    text = builtins.readFile ./app_name_plugin.sh;
    derivationArgs.buildInputs = [ pkgs.sketchybar ];
  };

  clockPlugin = pkgs.writeShellApplication rec {
    name = "clock_plugin";
    text = builtins.readFile ./clock_plugin.sh;
    derivationArgs.buildInputs = with pkgs; [
      aerospace
      sketchybar
    ];
    runtimeInputs = derivationArgs.buildInputs;
  };

  batteryPlugin = pkgs.writeShellApplication rec {
    name = "battery_plugin";
    text = builtins.readFile ./battery.sh;
    derivationArgs.buildInputs = with pkgs; [
      aerospace
      sketchybar
      gnugrep
    ];

    runtimeInputs = derivationArgs.buildInputs;
  };

  rc = pkgs.writeShellApplication rec {
    name = "sketchybarrc";
    text = builtins.readFile ./sketchybarrc.sh;
    derivationArgs.buildInputs =
      (with pkgs; [
        aerospace
        sketchybar
        gnugrep
      ])
      ++ [
        aerospacePlugin
        appNamePlugin
        clockPlugin
        batteryPlugin
      ];
    runtimeInputs = derivationArgs.buildInputs;
    runtimeEnv = themeEnv;
  };
in
{
  options = {
    psyclyx.services.sketchybar = {
      enable = lib.mkEnableOption "Sketchybar status bar";
      yOffset = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 8;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.sketchybar = {
      enable = true;
      config = "sketchybarrc";
      extraPackages = [
        aerospacePlugin
        appNamePlugin
        batteryPlugin
        clockPlugin
        pkgs.gnugrep
        rc
      ];
    };
  };
}
