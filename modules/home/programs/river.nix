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
    ];

    psyclyx.home = {
      programs = {
        alacritty.enable = lib.mkDefault true;
        whirlpool.enable = lib.mkDefault true;
        # kanshi applies the declared monitor layout and reapplies it on
        # hotplug. Only meaningful when monitors are declared.
        kanshi.enable = lib.mkDefault (monitors != {});
      };
      services.mako.enable = lib.mkDefault true;
    };

    # A fallback only: Whirlpool's own lock screen (services.whirlpool.lock,
    # programs/whirlpool.nix) is what locks. swaylock stays installed and
    # configured for when that cannot run (`swaylock` from a terminal).
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

    systemd.user.services.swaybg = {
      Unit = {
        Description = "Wallpaper (swaybg)";
        # River 0.4 delegates layer-shell placement to the window manager:
        # a zwlr_layer_surface created while no WM has bound
        # river_layer_shell_v1 is closed on the spot ("window manager did
        # not bind river_layer_shell_v1, closing layer surface"), and swaybg
        # drops that output and never retries — a black background for the
        # rest of the session. So swaybg must start only once whirlpool is
        # managing. This relies on whirlpool.service being Type=notify and
        # reporting READY only after it has bound the WM globals, which makes
        # After= a real readiness edge (with a Type=simple WM it only orders
        # process start and still races). A plain After= on an unloaded unit is a
        # no-op, so this is harmless without whirlpool.
        #
        # Not ordered on kanshi: swaybg follows wl_output globals and
        # layer-surface configures, so it redraws for whatever layout kanshi
        # applies later (mode/scale/position changes, profile switches,
        # hotplug). Established surfaces also survive a WM restart; only a
        # surface *created* while the WM is down (an output hotplugged
        # during a whirlpool restart) is lost — restart swaybg if that
        # ever happens.
        After = ["graphical-session.target" "whirlpool.service"];
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
