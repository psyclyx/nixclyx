{
  path = ["psyclyx" "home" "programs" "rofi-rbw"];
  description = "rofi-rbw (Bitwarden GUI picker)";
  gate = {config, ...}: config.psyclyx.home.programs.fuzzel.enable;
  config = {pkgs, ...}: {
    home.packages = [pkgs.rofi-rbw-wayland];

    xdg.configFile."rofi-rbw.rc".text = "selector=fuzzel";
  };
}
