{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let

  inherit (lib) mkEnableOption mkIf mkBefore getExe;

  inherit (pkgs.stdenv.hostPlatform) system;
  inherit (inputs.ghostty.packages."${system}") ghostty;

  cfg = config.psyclyx.programs.ghostty;
in
{
  options = {
    psyclyx.programs.ghostty = {
      enable = mkEnableOption "ghostty terminal emulator";
      defaultTerminal = mkEnableOption "setting as default terminal via TERMINAL environment variable";
    };
  };

  config = mkIf cfg.enable {
    programs.ghostty = {
      enable = true;
      package = ghostty;
    };

    home.sessionVariables = mkIf cfg.defaultTerminal {
      TERMINAL = "${getExe config.programs.ghostty.package} +new-window";
    };

    xdg.terminal-exec = {
      enable = true;
      settings.default = if cfg.defaultTerminal
        then mkBefore [ "com.mitchellh.ghostty.desktop" ]
        else [ "com.mitchellh.ghostty.desktop" ];
    };
  };
}
