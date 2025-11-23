{ config, lib }:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.psyclyx.programs.fzf;
in
{
  options = {
    psyclyx.programs.fzf = {
      enable = mkEnableOption "fzf fuzzy finder";
    };
  };

  config = {
    programs.fzf.enable = true;
  };
}
