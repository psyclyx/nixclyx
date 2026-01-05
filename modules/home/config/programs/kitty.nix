{ config, lib, ... }:
let
  cfg = config.psyclyx.programs.kitty;
in
{
  options = {
    psyclyx.programs.kitty = {
      enable = lib.mkEnableOption "Kitty terminal emulator";
      defaultTerminal = lib.mkEnableOption "setting as default terminal via TERMINAL environment variable";
    };
  };

  config = lib.mkIf cfg.enable {
    programs = {
      kitty = {
        enable = true;
        settings = {
          enable_audio_bell = false;
        };

        themeFile = "Doom_One";
        font = {
          size = 14;
          name = "Aporetic Sans Mono";
        };
      };
    };

    home.sessionVariables = lib.mkIf cfg.defaultTerminal {
      TERMINAL = lib.getExe config.programs.kitty.package;
    };

    xdg.terminal-exec = {
      enable = true;
      settings.default =
        if cfg.defaultTerminal then lib.mkBefore [ "kitty.desktop" ] else [ "kitty.desktop" ];
    };
  };
}
