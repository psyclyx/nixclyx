{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.hardware.glasgow;
in
{
  options.psyclyx.hardware.glasgow = {
    enable = lib.mkEnableOption "Glasgow digital interface explorer";
    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Users to put in the plugdev group";
    };
  };
  config = lib.mkIf cfg.enable {
    hardware.glasgow.enable = true;
    users.groups.plugdev.members = cfg.users;
    environment.systemPackages = with pkgs; [ glasgow ];
  };
}
