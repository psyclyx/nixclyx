{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.psyclyx.home.programs.fuzzel;
in
{
  options = {
    psyclyx.home.programs.fuzzel = {
      enable = mkEnableOption "Fuzzel application launcher";
    };
  };

  config = mkIf cfg.enable {
    programs.fuzzel = {
      enable = true;
    };
  };
}
