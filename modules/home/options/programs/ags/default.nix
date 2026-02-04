{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    mkEnableOption
    mkIf
    ;

  cfg = config.psyclyx.home.programs.ags;
in {
  options = {
    psyclyx.home.programs.ags = {
      enable = mkEnableOption "AGS (Aylur's GTK Shell)";
    };
  };

  config = mkIf cfg.enable {
    programs.ags = {
      enable = true;
      systemd.enable = true;
      configDir = ./shell;
      extraPackages = [
        pkgs.astal.tray
        pkgs.astal.battery
        pkgs.astal.wireplumber
        pkgs.astal.network
        pkgs.astal.apps
        pkgs.astal.powerprofiles
        pkgs.swayfx
      ];
    };
  };
}
