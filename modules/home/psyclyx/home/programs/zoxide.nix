{ config, lib, ... }:
let
  cfg = config.psyclyx.home.programs.zoxide;
in
{
  options = {
    psyclyx.home.programs.zoxide = {
      enable = lib.mkEnableOption "zoxide (enhanced cd)";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zoxide.enable = true;
  };
}
