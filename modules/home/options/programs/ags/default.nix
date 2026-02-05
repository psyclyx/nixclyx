{
  path = ["psyclyx" "home" "programs" "ags"];
  description = "AGS (Aylur's GTK Shell)";
  config = {pkgs, ...}: {
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
