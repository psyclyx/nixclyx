{ config, lib, ... }:
let
  cfg = config.psyclyx.programs.git;
  user = config.psyclyx.user;
in
{
  options = {
    psyclyx = {
      programs = {
        git = {
          enable = lib.mkEnableOption "Configure git.";
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    programs = {
      git = {
        enable = true;
        userName = user.name;
        userEmail = user.email;
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
