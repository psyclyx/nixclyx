{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.dbus ];
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
