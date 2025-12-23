{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.psyclyx.nixos.programs.glasgow;
in
{
  options = {
    psyclyx.nixos.programs.glasgow = {
      enable = mkEnableOption "Glasgow digital interface explorer";
      users = mkOption {
        type = types.listOf types.str;
        description = "Users to put in the plugdev group";
      };
    };
  };

  config = mkIf cfg.enable {
    psyclyx.nixos.programs.glasgow.users = config.users.groups.wheel.members;
    users.groups.plugdev.members = cfg.users;
    services.udev.packages = [ pkgs.glasgow ];
    environment.systemPackages = [ pkgs.glasgow ];
  };
}
