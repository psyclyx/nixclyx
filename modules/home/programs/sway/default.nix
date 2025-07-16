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
  imports = [ ./keybindings.nix ./theme.nix ];

  options = {
    psyclyx = {
      programs = {
        sway = {
          enable = lib.mkEnableOption "Sway config";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    wayland.windowManager.sway = {
      enable = true;
      package = null;
      config = {
        assigns = {
          "1" = [ { instance = "vscodium"; } ];
          "2" = [ { app_id = "firefox"; } ];
          "3" = [ { instance = "obsidian"; } ];
          "4" = [ { instance = "signal"; } ];
        };

        bars = [ { command = "${pkgs.waybar}/bin/waybar"; } ];
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
        workspaceAutoBackAndForth = true;
      };
    };
  };
}
