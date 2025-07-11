{ config, lib, ... }:
let
  cfg = config.psyclyx.programs.adb;
in
{
  options = {
    psyclyx = {
      programs = {
        adb = {
          enable = lib.mkEnableOption "Enable ADB and associated udev rules/groups.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs = {
      adb = {
        enable = true;
      };
    };
  };
}
