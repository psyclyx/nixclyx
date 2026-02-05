{nixclyx, lib, pkgs, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "services" "locate"];
  description = "Locate service";
  options = {
    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Users to put in the mlocate group";
    };
  };
  config = {cfg, config, ...}: {
    services.locate = {
      enable = true;
      interval = "hourly";
      package = pkgs.mlocate;
      pruneNames = [
        ".cache"
        ".git"
        "result"
        ".cargo"
        ".julia"
        ".direnv"
      ];
    };

    psyclyx.nixos.services.locate.users = config.users.groups.wheel.members;
    users.groups.mlocate.members = cfg.users;
  };
} args
