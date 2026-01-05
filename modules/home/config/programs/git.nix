{ config, lib, ... }:
let
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
        settings.user = lib.mapAttrs (_: lib.mkDefault) { inherit (user) name email; };
        iniContent = {
          pull.rebase = true;
          core.fsmonitor = true;
        };
      };
    };
  };
}
