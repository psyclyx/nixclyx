{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkDefault mkEnableOption mkIf;
  cfg = config.psyclyx.home.roles.shell;
in
{
  options = {
    psyclyx.home.roles.shell = {
      enable = mkEnableOption "Basic shell configuration and utilities";
    };
  };

  config = mkIf cfg.enable {
    psyclyx = {
      home = {
        programs = {
          ssh = {
            enable = mkDefault true;
          };
          zsh = {
            enable = mkDefault true;
          };
        };
      };
    };
  };
}
