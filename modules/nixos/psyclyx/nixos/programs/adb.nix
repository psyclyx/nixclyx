{ config, lib, ... }:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.psyclyx.nixos.programs.adb;
in
{
  options = {
    psyclyx.nixos.programs.adb = {
      enable = mkEnableOption "Enable ADB and associated udev rules/groups.";
      users = mkOption {
        type = types.listOf types.str;
        default = config.users.groups.wheel.members or [ ];
        description = "Users to add to the adbusers group.";
      };
    };
  };

  config = mkIf cfg.enable {
    programs.adb.enable = true;
    users.groups.adbusers.members = cfg.users;
  };
}
