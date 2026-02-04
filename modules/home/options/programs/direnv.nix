{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.home.programs.direnv;
in {
  options = {
    psyclyx.home.programs.direnv = {
      enable = lib.mkEnableOption "direnv";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      silent = true;
      nix-direnv.enable = true;
    };
  };
}
