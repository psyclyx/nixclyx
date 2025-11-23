{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.psyclyx.programs.direnv;
in
{
  options = {
    psyclyx.programs.direnv = {
      enable = mkEnableOption "direnv";
    };
  };

  config = mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      silent = true;
      nix-direnv.enable = true;
    };
  };
}
