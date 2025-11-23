{ config, lib, ... }:
let
  inherit (lib) mkDefault mkEnableOption mkIf;

  cfg = config.psyclyx.programs.zsh;
in
{
  options = {
    psyclyx.programs.zsh = {
      enable = mkEnableOption "Zsh shell with prezto";
    };
  };

  config = mkIf cfg.enable {
    programs = {
      zsh = {
        enable = true;
        dotDir = "${config.xdg.configHome}/zsh";
        enableVteIntegration = true;
      };
    };

    psyclyx.programs.shell.enable = mkDefault true;
  };
}
