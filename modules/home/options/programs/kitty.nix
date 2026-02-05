{
  path = ["psyclyx" "home" "programs" "kitty"];
  description = "Kitty terminal emulator";
  options = {lib, ...}: {
    defaultTerminal = lib.mkEnableOption "setting as default terminal via TERMINAL environment variable";
  };
  config = {cfg, config, lib, ...}: {
    programs = {
      kitty = {
        enable = true;
        font = {
          size = 14;
          name = "Aporetic Sans Mono";
        };

        settings = {
          enable_audio_bell = false;
        };

        themeFile = "Doom_One";
      };
    };

    home.sessionVariables = lib.mkIf cfg.defaultTerminal {
      TERMINAL = lib.getExe config.programs.kitty.package;
    };

    xdg.terminal-exec = {
      enable = true;
      settings.default =
        if cfg.defaultTerminal
        then lib.mkBefore ["kitty.desktop"]
        else ["kitty.desktop"];
    };
  };
}
