{
  path = [
    "psyclyx"
    "home"
    "programs"
    "river"
  ];
  description = "River dynamic tiling compositor";
  config = {
    config,
    lib,
    pkgs,
    ...
  }: let
    monitors = config.psyclyx.home.hardware.monitors;
    fuzzel = lib.getExe config.programs.fuzzel.package;
    swaylock = lib.getExe config.programs.swaylock.package;
    wayland-logout = lib.getExe pkgs.wayland-logout;

    power-menu = pkgs.writeShellScriptBin "river-power-menu" ''
      options="Lock\nLogout\nSuspend\nReboot\nShutdown"
      chosen=$(echo -e "$options" | ${fuzzel} --dmenu --prompt "Power: ")
      case $chosen in
        "Lock") ${swaylock} ;;
        "Logout") ${wayland-logout} ;;
        "Suspend") systemctl suspend ;;
        "Shutdown") systemctl poweroff ;;
        "Reboot") systemctl reboot ;;
      esac
    '';

    # Monitors with a declared ICC profile get a set-output-icc user service
    # that loads the profile (calibrated SDR) over psyclyx_color_management_v1
    # and holds the connection — stopping it reverts the output, like swaybg.
    # Targeted by monitor identity so the profile follows the panel.
    colorProfileMonitors = lib.filterAttrs (_: m: m.colorProfile != null) monitors;
    colorProfileServices =
      lib.mapAttrs' (
        name: m:
          lib.nameValuePair "set-output-icc-${name}" {
            Unit = {
              Description = "Load ICC color profile for ${m.identifier}";
              After = ["graphical-session.target" "kanshi.service"];
              PartOf = ["graphical-session.target"];
            };
            Service = {
              ExecStart = "${lib.getExe pkgs.psyclyx.set-output-icc} ${lib.escapeShellArg m.identifier} ${m.colorProfile}";
              Restart = "on-failure";
              RestartSec = 2;
            };
            Install.WantedBy = ["graphical-session.target"];
          }
      )
      colorProfileMonitors;

    # River 0.4 init script: kept minimal. The only thing that must run
    # from river's process tree is uwsm finalize (sends sd_notify to mark
    # wayland-wm@river.service as ready). All session services are
    # orchestrated by systemd via graphical-session.target.
    initScript = pkgs.writeShellScript "river-init" ''
      uwsm finalize
    '';
  in {
    home.packages =
      [
        pkgs.brightnessctl
        pkgs.pulseaudio
        pkgs.wayland-logout
        power-menu
      ]
      ++ lib.optional (colorProfileMonitors != {}) pkgs.psyclyx.set-output-icc;

    psyclyx.home = {
      programs = {
        alacritty.enable = lib.mkDefault true;
        tidepool.enable = lib.mkDefault true;
        # fuzzel is the launcher/dmenu (used by the power menu here and the
        # sway menus).
        fuzzel.enable = lib.mkDefault true;
        # kanshi applies the declared monitor layout and reapplies it on
        # hotplug. Only meaningful when monitors are declared.
        kanshi.enable = lib.mkDefault (monitors != {});
      };
      services.mako.enable = lib.mkDefault true;
    };

    programs.swaylock = {
      enable = true;
      package = lib.mkDefault pkgs.swaylock-effects;
      settings = {
        indicator = true;
        screenshots = true;
        clock = true;
        show-failed-attempts = true;
        indicator-radius = lib.mkDefault 280;
        indicator-thickness = lib.mkDefault 4;
        effect-pixelate = lib.mkDefault 8;
        grace = lib.mkDefault 3;
      };
    };

    xdg.configFile."river/init" = {
      source = initScript;
      executable = true;
    };

    systemd.user.services =
      colorProfileServices
      // {
        swaybg = {
          Unit = {
            Description = "Wallpaper (swaybg)";
            # Order after kanshi so the wallpaper is drawn against the final
            # monitor layout (position/mode/scale) rather than the default
            # output geometry, which made it paint too early. The kanshi unit
            # only exists when monitors are declared; a plain After= on an
            # unloaded unit is a no-op, so this is safe either way.
            After = ["graphical-session.target" "kanshi.service"];
            PartOf = ["graphical-session.target"];
          };
          Service = {
            ExecStart = "${lib.getExe pkgs.swaybg} -i ${config.stylix.image} -m fill";
            Restart = "on-failure";
            RestartSec = 2;
          };
          Install.WantedBy = ["graphical-session.target"];
        };
      };
  };
}
