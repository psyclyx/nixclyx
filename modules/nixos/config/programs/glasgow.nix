{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.programs.glasgow;
in
{
  options.psyclyx.programs.glasgow = {
    enable = lib.mkEnableOption "Glasgow digital interface explorer";
    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Users to put in the plugdev group";
    };
  };

  config = lib.mkIf cfg.enable {
    psyclyx.programs.glasgow.users = config.users.groups.wheel.members;

    users.groups.plugdev.members = cfg.users;

    services.udev.packages = [ pkgs.glasgow ];

    environment.systemPackages = [ pkgs.glasgow ];
  };
}
