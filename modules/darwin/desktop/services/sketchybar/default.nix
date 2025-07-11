{
  config,
  pkgs,
  lib,
  ...
}:
let
  colors = import ../../../../home/themes/angel.nix { inherit lib; };
  themeEnv =
    with colors.colorUtils;
    mkThemeEnv [
      (transform.withAlpha 1.0)
      transform.withOx
    ];
  transparentTheme =
    with colors.colorUtils;
    mkTheme [
      (transform.withAlpha 0.3)
      transform.withOx
    ];

  aerospacePlugin = pkgs.writeShellApplication rec {
    name = "aerospace_plugin";
    text = builtins.readFile ./aerospace_plugin.sh;
    derivationArgs.buildInputs = with pkgs; [
      aerospace
      sketchybar
    ];

    runtimeInputs = derivationArgs.buildInputs;
    runtimeEnv = themeEnv;
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
    runtimeEnv = themeEnv // {
      "BAR_BACKGROUND" = transparentTheme.background;
      "Y_OFFSET" = config.psyclyx.sketchybar.yOffset;
    };
  };
in
{
  options = {
    psyclyx.sketchybar.yOffset = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 8;
    };
  };

  config = {
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
