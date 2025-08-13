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
          wrapping = "force";
          newWindow = "urgent";
        };
        window.border = 2;
        workspaceAutoBackAndForth = true;
        output = {
          "*".scale = "1";
        };
      };
    };
  };
}
