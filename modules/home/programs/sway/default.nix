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
        blur enable
        blur_xray disable
        blur_radius 6
        blur_noise 0.2
        #blur_contrast 1
        blur_passes 1

        corner_radius 6

        default_dim_inactive 0.1

        shadows enable
        shadows_on_csd enable
        shadow_blur_radius 6
        shadow_offset 4 8
        shadow_color #${config.lib.stylix.colors.base01}AA
        shadow_inactive_color #${config.lib.stylix.colors.base00}7F

        layer_effects "waybar" {
          blur enable
          blur_xray enable
          shadows enable
          corner_radius 4
        }

        titlebar_border_thickness 0
        titlebar_separator disable
        titlebar_padding 4 4
      '';
      config = {
        bars = [ { command = "${pkgs.waybar}/bin/waybar"; } ];
        gaps = {
          smartBorders = "on";
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
              border = base04;
              childBorder = base04;
              indicator = base04;
              text = base04;
            };
            unfocused = {
              background = base00;
              border = base03;
              childBorder = base03;
              indicator = base03;
              text = base03;
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
