{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.programs.zsh;
in
{
  options = {
    psyclyx.programs.zsh = {
      enable = lib.mkEnableOption "zsh shell";
    };
  };

  config = lib.mkIf cfg.enable {
    programs = {
      zsh = {
        enable = true;
        enableGlobalCompInit = false;
      };
    };
  };
}
