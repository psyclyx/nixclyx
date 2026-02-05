{nixclyx, lib, pkgs, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "programs" "zsh"];
  description = "Zsh config";
  options = {
    defaultShell = lib.mkEnableOption "Zsh as the default shell";
  };
  config = {cfg, ...}: {
    environment.pathsToLink = ["/share/zsh"];
    programs.zsh = {
      enable = true;
      enableGlobalCompInit = false;
    };

    users.defaultUserShell = lib.mkIf cfg.defaultShell pkgs.zsh;
  };
} args
