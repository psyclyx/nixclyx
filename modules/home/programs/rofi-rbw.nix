{
  path = ["psyclyx" "home" "programs" "rofi-rbw"];
  description = "rofi-rbw (Bitwarden GUI picker)";
  config = {config, lib, pkgs, ...}: {
    home.packages = [pkgs.rofi-rbw-wayland];

    xdg.configFile."rofi-rbw.rc".text = lib.mkIf config.psyclyx.home.programs.fuzzel.enable
      "selector=fuzzel";
  };
}
