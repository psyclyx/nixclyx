{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.darwin.programs.zsh;
in {
  options.psyclyx.darwin.programs.zsh = {
    enable = lib.mkEnableOption "zsh shell";
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
