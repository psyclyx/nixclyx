{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.psyclyx.nixos.programs.zsh;
in
{
  options = {
    psyclyx.nixos.programs.zsh = {
      defaultShell = mkEnableOption "Zsh as the default shell";
      enable = mkEnableOption "Zsh config";
    };
  };

  config = mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      enableGlobalCompInit = false;
    };

    users.defaultUserShell = mkIf cfg.defaultShell pkgs.zsh;
  };
}
