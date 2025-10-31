{ config, lib, ... }:
let
  cfg = config.psyclyx.programs.fuzzel;
in
{
  options = {
    psyclyx.programs.fuzzel = {
      enable = lib.mkEnableOption "Fuzzel application launcher";
    };
  };
  config = lib.mkIf cfg.enable {
    programs.fuzzel = {
      enable = true;
    };
  };
}
