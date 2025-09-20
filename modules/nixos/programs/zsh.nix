{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.programs.zsh;
in
{
  options = {
    psyclyx.programs.zsh = {
      defaultShell = lib.mkEnableOption "Zsh as the default shell" // {
        default = cfg.enable;
      };
      enable = lib.mkEnableOption "Zsh config";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      enableGlobalCompInit = false;
    };
    users.defaultUserShell = lib.mkIf cfg.defaultShell pkgs.zsh;
  };
}
