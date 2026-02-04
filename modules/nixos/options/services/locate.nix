{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.psyclyx.nixos.services.locate;
in {
  options = {
    psyclyx.nixos.services.locate = {
      enable = lib.mkEnableOption "Locate service";
      users = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Users to put in the mlocate group";
      };
    };
  };

  config = lib.mkIf cfg.enable {
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
}
