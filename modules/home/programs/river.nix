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
    shoal-dmenu = "${lib.getExe config.programs.shoal.package} --dmenu";
    swaylock = lib.getExe config.programs.swaylock.package;
    wayland-logout = lib.getExe pkgs.wayland-logout;
    wlr-randr = "${pkgs.wlr-randr}/bin/wlr-randr";

    # Script that resolves monitor identifiers to connectors at runtime
    apply-layout = pkgs.writeShellScript "apply-monitor-layout" ''
      set -euo pipefail
      json=$(${wlr-randr} --json)
      resolve() {
        local ident="$1"
        echo "$json" | ${pkgs.jq}/bin/jq -r --arg id "$ident" \
          '.[] | select(.description | startswith($id)) | .name' | head -1
      }
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (_: m: let
        pos = "--pos ${toString m.position.x},${toString m.position.y}";
        mode = lib.optionalString (m.mode != null) " --mode ${toString m.mode.width}x${toString m.mode.height}";
        scale = lib.optionalString (m.scale != 1.0) " --scale ${toString m.scale}";
      in ''conn=$(resolve ${lib.escapeShellArg m.identifier}) && [ -n "$conn" ] && ${wlr-randr} --output "$conn" ${pos}${mode}${scale}'') (lib.filterAttrs (_: m: m.enable) monitors))}
    '';

    power-menu = pkgs.writeShellScriptBin "river-power-menu" ''
      options="Lock\nLogout\nSuspend\nReboot\nShutdown"
      chosen=$(echo -e "$options" | ${shoal-dmenu} -p "Power: ")
      case $chosen in
        "Lock") ${swaylock} ;;
        "Logout") ${wayland-logout} ;;
        "Suspend") systemctl suspend ;;
        "Shutdown") systemctl poweroff ;;
        "Reboot") systemctl reboot ;;
      esac
    '';

    # River 0.4 init script: kept minimal. The only thing that must run
    # from river's process tree is uwsm finalize (sends sd_notify to mark
    # wayland-wm@river.service as ready). All session services are
    # orchestrated by systemd via graphical-session.target.
    initScript = pkgs.writeShellScript "river-init" ''
      uwsm finalize
    '';

  in {
    home.packages = [
      pkgs.brightnessctl
      pkgs.pulseaudio
      pkgs.wayland-logout
      power-menu
    ];

    psyclyx.home = {
      programs = {
        alacritty.enable = lib.mkDefault true;
        tidepool.enable = lib.mkDefault true;
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

    systemd.user.services.wlr-randr = lib.mkIf (monitors != {}) {
      Unit = {
        Description = "Apply monitor layout via wlr-randr";
        PartOf = ["graphical-session.target"];
      };
      Service = {
        Type = "oneshot";
        ExecStart = apply-layout;
        RemainAfterExit = true;
      };
      Install.WantedBy = ["graphical-session.target"];
    };

    systemd.user.services.swaybg = {
      Unit = {
        Description = "Wallpaper (swaybg)";
        After = ["tidepool.service"];
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
}
