{
  path = ["psyclyx" "home" "programs" "ghostty"];
  description = "ghostty terminal emulator";
  options = {lib, ...}: {
    defaultTerminal = lib.mkEnableOption "setting as default terminal via TERMINAL environment variable";
  };
  config = {
    cfg,
    config,
    lib,
    ...
  }: {
    programs.ghostty = {
      enable = true;
      settings = {
        shell-integration-features = "ssh-env";
      };
    };

    home.sessionVariables = lib.mkIf cfg.defaultTerminal {
      TERMINAL = "${lib.getExe config.programs.ghostty.package} +new-window";
    };

    xdg.terminal-exec = {
      enable = true;
      settings.default =
        if cfg.defaultTerminal
        then lib.mkBefore ["com.mitchellh.ghostty.desktop"]
        else ["com.mitchellh.ghostty.desktop"];
    };
  };
}
