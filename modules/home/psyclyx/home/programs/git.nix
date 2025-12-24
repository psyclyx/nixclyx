{ config, lib, ... }:
let
  cfg = config.psyclyx.home.programs.git;
  info = config.psyclyx.home.info;
in
{
  options = {
    psyclyx.home.programs.git = {
      enable = lib.mkEnableOption "git version control";
    };
  };

  config = lib.mkIf cfg.enable {
    programs = {
      git = {
        enable = true;
        settings.user = lib.mapAttrs (_: lib.mkDefault) { inherit (info) name email; };
        iniContent = {
          pull.rebase = true;
          core.fsmonitor = true;
        };
      };
    };
  };
}
