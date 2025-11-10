{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.roles.shell;
in
{
  options = {
    psyclyx.roles.shell = {
      enable = lib.mkEnableOption "Basic shell configuration and utilities";
    };
  };

  config = lib.mkIf cfg.enable {
    psyclyx = {
      programs = {
        ssh = {
          enable = lib.mkDefault true;
        };
        zsh = {
          enable = lib.mkDefault true;
        };
      };
    };
  };
}
