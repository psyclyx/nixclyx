{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkBefore
    getExe
    ;
  cfg = config.psyclyx.programs.alacritty;
in
{
  options = {
    psyclyx.programs.alacritty = {
      enable = mkEnableOption "Alacritty terminal emulator";
      defaultTerminal = mkEnableOption "setting as default terminal via TERMINAL environment variable";
    };
  };

  config = mkIf cfg.enable {

    programs.alacritty = {
      enable = true;
      package = pkgs.alacritty-graphics;
      settings = {
        window = {
          option_as_alt = "Both";
        };
      };
    };

    home.sessionVariables = mkIf cfg.defaultTerminal {
      TERMINAL = getExe config.programs.alacritty.package;
    };

    xdg.terminal-exec = {
      enable = true;
      settings.default =
        if cfg.defaultTerminal then mkBefore [ "Alacritty.desktop" ] else [ "Alacritty.desktop" ];
    };
  };
}
