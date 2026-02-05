{
  path = ["psyclyx" "nixos" "programs" "sway"];
  description = "swayfx wm";
  config = {pkgs, ...}: {
    environment.systemPackages = [
      pkgs.dbus
      pkgs.qt5.qtwayland
    ];

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
