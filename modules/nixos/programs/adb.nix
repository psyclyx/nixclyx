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
          users = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Users to add to the adbusers group.";
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.adb.enable = true;
    users.groups.adbusers = cfg.users;
  };
}
