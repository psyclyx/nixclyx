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
  cfg = config.psyclyx.nixos.services.locate;
in
{
  options = {
    psyclyx.nixos.services.locate = {
      enable = mkEnableOption "Locate service";
      users = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Users to put in the mlocate group";
      };
    };
  };

  config = mkIf cfg.enable {
    psyclyx.nixos.services.locate.users = config.users.groups.wheel.members;
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

    users.groups.mlocate.members = cfg.users;
  };
}
