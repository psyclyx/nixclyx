{nixclyx, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "home" "programs" "fastfetch"];
  description = "Fastfetch system info";
  config = _: {
    programs.fastfetch = {
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
  };
} args
