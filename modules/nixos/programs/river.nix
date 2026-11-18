{
  path = ["psyclyx" "nixos" "programs" "river"];
  description = "River wayland compositor with UWSM session management";
  config = {pkgs, lib, ...}: {
    # Use the wlroots Vulkan renderer. wlroots still labels it experimental,
    # so revisit if the session proves unstable.
    environment.variables.WLR_RENDERER = "vulkan";

    environment.systemPackages = [
      pkgs.psyclyx.river
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
      # Whirlpool's lock screen (`whirlpool lock`) checks passwords with this
      # PAM service; without it PAM falls back to `other`, which refuses
      # every password. (swaylock, kept as a fallback, has its own.)
      pam.services.whirlpool-lock = {};
    };

    xdg.portal = {
      enable = lib.mkDefault true;
      wlr.enable = lib.mkDefault true;
      extraPortals = [pkgs.xdg-desktop-portal-gtk];
      config.river = {
        default = ["gtk"];
        "org.freedesktop.impl.portal.ScreenCast" = ["wlr"];
        "org.freedesktop.impl.portal.Screenshot" = ["wlr"];
        "org.freedesktop.impl.portal.Inhibit" = ["none"];
      };
    };
  };
}
