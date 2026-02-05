{
  path = ["psyclyx" "nixos" "programs" "zsh"];
  description = "Zsh config";
  options = {lib, ...}: {
    defaultShell = lib.mkEnableOption "Zsh as the default shell";
  };
  config = {cfg, lib, pkgs, ...}: {
    environment.pathsToLink = ["/share/zsh"];
    programs.zsh = {
      enable = true;
      enableGlobalCompInit = false;
    };

    users.defaultUserShell = lib.mkIf cfg.defaultShell pkgs.zsh;
  };
}
