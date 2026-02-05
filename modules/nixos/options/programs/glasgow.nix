{nixclyx, lib, pkgs, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "programs" "glasgow"];
  description = "Glasgow digital interface explorer";
  options = {
    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Users to put in the plugdev group";
    };
  };
  config = {cfg, config, ...}: {
    psyclyx.nixos.programs.glasgow.users = config.users.groups.wheel.members;
    users.groups.plugdev.members = cfg.users;
    services.udev.packages = [pkgs.glasgow];
    environment.systemPackages = [pkgs.glasgow];
  };
} args
