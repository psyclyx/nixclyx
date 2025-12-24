{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.nixos.programs.zsh;
in
{
  options = {
    psyclyx.nixos.programs.zsh = {
      defaultShell = lib.mkEnableOption "Zsh as the default shell";
      enable = lib.mkEnableOption "Zsh config";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.pathsToLink = [ "/share/zsh" ];
    programs.zsh = {
      enable = true;
      enableGlobalCompInit = false;
    };

    users.defaultUserShell = lib.mkIf cfg.defaultShell pkgs.zsh;
  };
}
