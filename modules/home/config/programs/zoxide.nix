{ config, lib, ... }:
let
  cfg = config.psyclyx.programs.zoxide;
in
{
  options = {
    psyclyx.programs.zoxide = {
      enable = lib.mkEnableOption "zoxide (enhanced cd)";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zoxide.enable = true;
  };
}
