{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.programs.sway;
in
{
  imports = [ ./keybindings.nix ];

  options.psyclyx.programs.sway = {
    enable = lib.mkEnableOption "Sway config";
  };

  config = lib.mkIf cfg.enable {
    wayland.windowManager.sway = {
      enable = true;
      package = null;
      extraConfig = ''
        titlebar_border_thickness 0
        titlebar_padding 4 4
      '';
      config = {
        bars = [ { command = "${pkgs.waybar}/bin/waybar"; } ];
        gaps = {
          outer = 4;
          inner = 8;
        };
        colors =
          with config.lib.stylix.colors.withHashtag;
          lib.mkForce {
            background = base01;
            focused = {
              background = base02;
              border = base07;
              childBorder = base07;
              indicator = base02;
              text = base07;
            };
            focusedInactive = {
              background = base01;
              border = base02;
              childBorder = base02;
              indicator = base01;
              text = base05;
            };
            unfocused = {
              background = base00;
              border = base00;
              childBorder = base00;
              indicator = base00;
              text = base04;
            };
            urgent = {
              background = base02;
              border = base02;
              childBorder = base02;
              indicator = base02;
              text = base07;
            };
          };
        defaultWorkspace = "workspace number 1";
        floating = {
          criteria = [
            { app_id = "xdg-desktop-portal-gtk"; }
            {
              app_id = "firefox";
              title = "Library";
            }
          ];
        };
        focus = {
          newWindow = "smart";
        };
        window = {
          titlebar = false;
          border = 4;
        };
        workspaceAutoBackAndForth = true;
        output = {
          "*".scale = "1";
        };
      };
    };
  };
}
