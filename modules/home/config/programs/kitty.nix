{ config, lib, ... }:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkBefore
    getExe
    ;
  cfg = config.psyclyx.programs.kitty;
in
{
  options = {
    psyclyx.programs.kitty = {
      enable = mkEnableOption "Kitty terminal emulator";
      defaultTerminal = mkEnableOption "setting as default terminal via TERMINAL environment variable";
    };
  };

  config = mkIf cfg.enable {
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

    home.sessionVariables = mkIf cfg.defaultTerminal {
      TERMINAL = getExe config.programs.kitty.package;
    };

    xdg.terminal-exec = {
      enable = true;
      settings.default =
        if cfg.defaultTerminal then mkBefore [ "kitty.desktop" ] else [ "kitty.desktop" ];
    };
  };
}
