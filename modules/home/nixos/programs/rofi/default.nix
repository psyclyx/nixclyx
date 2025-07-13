{ pkgs, config, ... }:
{
  home.file."bin/rofi-session".source = ./rofi-session.sh;
  home.file."bin/rofi-session".executable = true;
  home.file."bin/rofi-prompt".source = ./rofi-prompt.sh;
  home.file."bin/rofi-prompt".executable = true;
  home.file."bin/sway-logout".source = ./sway-logout.sh;
  home.file."bin/sway-logout".executable = true;

  imports = [ ./theme.nix ];

  programs = {
    rofi = {
      enable = true;
      font = "Aporetic Sans 16";
      package = pkgs.rofi-wayland;
      extraConfig = {
        case-sensitive = false;
        display-drun = "drun: ";
        modi = [
          "drun"
          "run"
        ];
        show-icons = true;
      };
    };
  };
}
