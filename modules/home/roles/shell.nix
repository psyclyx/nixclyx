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
        curl
        dtach
        fd
        htop
        killall
        jq
        rclone
        ripgrep
        tree
        wget
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
