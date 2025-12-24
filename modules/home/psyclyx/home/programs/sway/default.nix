{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkDefault
    mkEnableOption
    mkForce
    mkIf
    ;

  cfg = config.psyclyx.home.programs.sway;
in
{
  imports = [
    ./keybindings.nix
    ./swaylock.nix
    ./waybar.nix
  ];

  options = {
    psyclyx.home.programs.sway = {
      enable = mkEnableOption "Sway window manager";
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      pulseaudio
      grim
      slurp
    ];

    psyclyx = {
      home = {
        programs = {
          alacritty.enable = mkDefault true;
          fuzzel.enable = mkDefault true;
          waybar.enable = mkDefault true;
        };
        services = {
          mako.enable = mkDefault true;
        };
      };
    };

    wayland.windowManager.sway = {
      enable = true;
      package = null;
      extraConfig = ''
        blur enable
        blur_xray disable
        blur_radius 4
        blur_noise 0.2
        blur_contrast 1.1
        blur_brightness 1
        blur_passes 1

        corner_radius 6

        default_dim_inactive 0.15

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
        }

        layer_effects "fuzzel" {
          blur enable
          blur_xray disable
          blur_ignore_transparent true
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
          let
            c = config.lib.stylix.colors.withHashtag;
          in
          mkForce {
            background = c.base01;
            focused = {
              background = c.base02;
              border = c.base07;
              childBorder = c.base07;
              indicator = c.base02;
              text = c.base07;
            };

            focusedInactive = {
              background = c.base01;
              border = c.base04;
              childBorder = c.base04;
              indicator = c.base04;
              text = c.base04;
            };

            unfocused = {
              background = c.base00;
              border = c.base03;
              childBorder = c.base03;
              indicator = c.base03;
              text = c.base03;
            };
            urgent = {
              background = c.base02;
              border = c.base02;
              childBorder = c.base02;
              indicator = c.base02;
              text = c.base07;
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
