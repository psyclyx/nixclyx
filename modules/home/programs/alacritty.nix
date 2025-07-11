{ pkgs, lib, ... }:
let
  colors = import ../themes/angel.nix { inherit lib; };
  theme = with colors.colorUtils; mkTheme [ transform.withHash ];
in
{
  programs = {
    alacritty = {
      enable = true;
      settings = {
        window = {
          option_as_alt = "Both";
        };
        font = {
          normal = {
            family = "Aporetic Sans Mono";
          };
          size = 12;
        };
        colors = {
          primary = {
            background = theme.terminal.black;
            foreground = theme.terminal.white;
          };
          cursor = {
            text = theme.terminal.black;
            cursor = theme.terminal.white;
          };
          normal = {
            black = theme.terminal.black;
            red = theme.terminal.red;
            green = theme.terminal.green;
            yellow = theme.terminal.yellow;
            blue = theme.terminal.blue;
            magenta = theme.terminal.magenta;
            cyan = theme.terminal.cyan;
            white = theme.terminal.white;
          };
          bright = {
            black = theme.terminal.bright_black;
            red = theme.terminal.bright_red;
            green = theme.terminal.bright_green;
            yellow = theme.terminal.bright_yellow;
            blue = theme.terminal.bright_blue;
            magenta = theme.terminal.bright_magenta;
            cyan = theme.terminal.bright_cyan;
            white = theme.terminal.bright_white;
          };
        };
      };
    };
  };
}
