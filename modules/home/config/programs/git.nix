{ config, lib, ... }:
let
  inherit (lib) mkDefault;

  cfg = config.psyclyx.programs.git;
  user = config.psyclyx.user;
in
{
  options = {
    psyclyx.programs.git = {
      enable = lib.mkEnableOption "git version control";
    };
  };
  config = lib.mkIf cfg.enable {
    programs = {
      git = {
        enable = true;
        settings.user.name = mkDefault user.name;
        settings.user.email = mkDefault user.email;
        iniContent = {
          "pull" = {
            "rebase" = true;
          };
          "core" = {
            "fsmonitor" = true;
          };
        };
      };
    };
  };
}
