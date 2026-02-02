{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.psyclyx.nixos.programs.sway;
in {
  options = {
    psyclyx.nixos.programs.sway = {
      enable = lib.mkEnableOption "swayfx wm";
    };
  };

  config = lib.mkIf cfg.enable {
    # dbus service is started by nixpkgs module
    environment.systemPackages = [
      pkgs.dbus
      pkgs.qt5.qtwayland
    ];

    # https://nixos.wiki/wiki/Sway#Inferior_performance_compared_to_other_distributions
    security = {
      rtkit.enable = true;

      pam = {
        loginLimits = [
          {
            domain = "@users";
            item = "rtprio";
            type = "-";
            value = 1;
          }
        ];
      };
    };

    programs = {
      light.enable = true;

      sway = {
        enable = true;
        package = pkgs.swayfx;
        extraOptions = ["--unsupported-gpu"];
        wrapperFeatures.gtk = true;
        extraPackages = [
          pkgs.wev
          pkgs.wl-clipboard
          pkgs.wtype
        ];

        extraSessionCommands = ''
          export SDL_VIDEODRIVER=wayland
          export QT_QPA_PLATFORM=wayland-egl
          export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
          export _JAVA_AWT_WM_NONREPARENTING=1
        '';
      };
    };
  };
}
