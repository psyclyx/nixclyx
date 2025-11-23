{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.psyclyx.programs.zoxide;
in
{
  options = {
    psyclyx.programs.zoxide = {
      enable = mkEnableOption "zoxide (enhanced cd)";
    };
  };

  config = mkIf cfg.enable {
    programs.zoxide.enable = true;
  };
}
