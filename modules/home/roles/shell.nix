{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfgEnabled = config.psyclyx.roles.shell;
in
{
  options = {
    psyclyx = {
      roles = {
        shell = lib.mkEnableOption "basic shell config";
      };
    };
  };

  config = lib.mkIf cfgEnabled {
    home = {
      packages = with pkgs; [
        fd
        ripgrep
      ];
    };

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
