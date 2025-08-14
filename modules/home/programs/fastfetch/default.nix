{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.psyclyx.programs.fastfetch;
in
{
  options.psyclyx.programs.fastfetch.enable = lib.mkEnableOption "fastfetch";
  config.programs.fastfetch = lib.mkIf cfg.enable {
    enable = true;
    settings = {
      logo = {
        source = ./psyclyx.sixel;
        type = "raw";
        height = 15;
        width = 37;
      };
      modules = [
        "title"
        "separator"
        "os"
        "host"
        "kernel"
        "uptime"
        "packages"
        "shell"
        "display"
        "de"
        "wm"
        "terminal"
        "terminalfont"
        "cpu"
        "gpu"
        "memory"
        "swap"
        "disk"
        "colors"
      ];
    };
  };
}
