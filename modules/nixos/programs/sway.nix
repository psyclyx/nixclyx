{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.dbus ];

  # Wiki claims this improves performance:
  # https://nixos.wiki/wiki/Sway#Inferior_performance_compared_to_other_distributions
  security = {
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
    sway = {
      enable = true;
      wrapperFeatures = {
        gtk = true;
      };
      extraPackages = [
        pkgs.wl-clipboard
        pkgs.wtype
      ];
      extraOptions = [ "--unsupported-gpu" ];
      extraSessionCommands = ''
        export SDL_VIDEODRIVER=wayland
        export QT_QPA_PLATFORM=wayland
        export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
        export _JAVA_AWT_WM_NONREPARENTING=1
        NIXOS_OZONE_WL=1
      '';
    };
  };
}
