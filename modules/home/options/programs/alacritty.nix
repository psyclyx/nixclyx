{nixclyx, lib, pkgs, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "home" "programs" "alacritty"];
  description = "Alacritty terminal emulator";
  options = {
    defaultTerminal = lib.mkEnableOption "setting as default terminal via TERMINAL environment variable";
  };
  config = {cfg, config, ...}: {
    programs.alacritty = {
      enable = true;
      package = pkgs.alacritty-graphics;
      settings = {
        window = {
          option_as_alt = "Both";
        };
      };
    };

    home.sessionVariables = lib.mkIf cfg.defaultTerminal {
      TERMINAL = lib.getExe config.programs.alacritty.package;
    };

    xdg.terminal-exec = {
      enable = true;
      settings.default =
        if cfg.defaultTerminal
        then lib.mkBefore ["Alacritty.desktop"]
        else ["Alacritty.desktop"];
    };
  };
} args
