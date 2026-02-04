{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.psyclyx.home.config.workstation;
in {
  options.psyclyx.home.config.workstation = {
    enable = lib.mkEnableOption "psyc workstation home config";
  };

  config = lib.mkIf cfg.enable {
    psyclyx.home.config.base.enable = true;

    home.packages = [
      pkgs.element-desktop
      pkgs.firefox-bin
      pkgs.signal-desktop-bin
    ];

    psyclyx.home = {
      programs = {
        alacritty.enable = true;
        ghostty = {
          enable = true;
          defaultTerminal = true;
        };
        sway.enable = true;
      };
    };
  };
}
