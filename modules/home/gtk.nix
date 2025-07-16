{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.gtk;
in
{
  options = {
    psyclyx = {
      gtk = {
        enable = lib.mkEnableOption "GTK config";
      };
    };
  };
  config = lib.mkIf cfg.enable {
    gtk = {
      enable = true;
      font = {
        name = "NotoSans Nerd Font";
        size = 12;
      };

      theme = {
        name = "Graphite-Light";
        package = pkgs.graphite-gtk-theme;
      };

      iconTheme = {
        name = "Tela";
        package = pkgs.tela-icon-theme;
      };
    };
  };
}
