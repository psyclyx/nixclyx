{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  inherit (inputs.ghostty.packages."${system}") ghostty;

  cfg = config.psyclyx.programs.ghostty;
in
{
  options = {
    psyclyx.programs.ghostty = {
      enable = lib.mkEnableOption "ghostty terminal emulator";
      defaultTerminal = lib.mkEnableOption "setting as default terminal via TERMINAL environment variable";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.ghostty = {
      enable = true;
      package = ghostty;
      settings = {
        shell-integration-features = "ssh-terminfo,ssh-env";
      };
    };

    home.sessionVariables = lib.mkIf cfg.defaultTerminal {
      TERMINAL = "${lib.getExe config.programs.ghostty.package} +new-window";
    };

    xdg.terminal-exec = {
      enable = true;
      settings.default =
        if cfg.defaultTerminal then
          lib.mkBefore [ "com.mitchellh.ghostty.desktop" ]
        else
          [ "com.mitchellh.ghostty.desktop" ];
    };
  };
}
