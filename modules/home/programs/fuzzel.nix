{ config, lib, ... }:
let
  cfg = config.psyclyx.programs.fuzzel;
in
{
  options.psyclyx.programs.fuzzel.enable = lib.mkEnableOption "fuzzel";
  config = lib.mkIf cfg.enable {
    programs.fuzzel = {
      enable = true;
    };
  };
}
