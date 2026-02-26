{
  path = ["psyclyx" "nixos" "programs" "river"];
  description = "River wayland compositor with UWSM session management";
  config = {pkgs, lib, ...}: {
    environment.systemPackages = [
      pkgs.river-classic
      pkgs.dbus
      pkgs.qt5.qtwayland
      pkgs.wl-clipboard
      pkgs.wev
      pkgs.wtype
      pkgs.wlr-randr
    ];

    programs.uwsm = {
      enable = true;
      waylandCompositors.river = {
        prettyName = "River";
        comment = "River dynamic tiling Wayland compositor";
        binPath = "/run/current-system/sw/bin/river";
      };
    };

    hardware.graphics.enable = lib.mkDefault true;

    security = {
      rtkit.enable = true;
      pam.loginLimits = [
        {
          domain = "@users";
          item = "rtprio";
          type = "-";
          value = 1;
        }
      ];
    };

    programs.light.enable = true;

    xdg.portal = {
      enable = lib.mkDefault true;
      wlr.enable = lib.mkDefault true;
      extraPortals = [pkgs.xdg-desktop-portal-gtk];
    };
  };
}
