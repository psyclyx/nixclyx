{ pkgs, ... }:
let
  sb = "${pkgs.sketchybar}/bin/sketchybar";
  modeBadge = icon: drawing: "exec-and-forget ${sb} --set mode icon=${icon} drawing=${drawing}";

  switch = mode: draw: [
    (modeBadge mode draw)
    "mode ${mode}"
  ];

  toMain = switch "main" "off";
  toMove = switch "move" "on";
  toCommand = switch "command" "on";
  toService = switch "service" "on";

  _kitty = "exec-and-forget ${pkgs.kitty}/bin/kitty --single-instance -d ~";
  alacritty = "exec-and-forget ${pkgs.alacritty}/bin/alacritty";
  term = alacritty;

  trigger-workspace-change = "${sb} --trigger aerospace_workspace_change";
  exec-twc = "exec-and-forget ${trigger-workspace-change}";

in
{
  services.aerospace = {
    enable = true;
    settings = {
      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = false;

      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";

      exec-on-workspace-change = [
        "/bin/bash"
        "-c"
        "${trigger-workspace-change} FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE"
      ];

      automatically-unhide-macos-hidden-apps = true;

      gaps = {
        inner.horizontal = 0;
        inner.vertical = 0;
        outer.left = 0;
        outer.bottom = 0;
        outer.top = [
          #{monitor."BenQ RD280U" = 38;}
          { monitor."Built-in Retina Display" = 0; }
          38
        ];
      };

      key-mapping.preset = "qwerty";

      mode.main.binding = {
        alt-enter = toCommand;
      };

      mode.command.binding = {
        esc = toMain;
        enter = toMove;

        shift-semicolon = toService;

        #o = ["exec-and-forget ${pkgs.kitty}/bin/kitty --single-instance -d ~"] ++ toMain;
        o = [ term ] ++ toMain;

        x = [ "close" ] ++ toMain;

        m = [ "fullscreen" ] ++ toMain;
        comma = [ "layout floating tiling" ] ++ toMain;
        period = [ "layout tiles horizontal vertical" ] ++ toMain;
        slash = [ "layout accordion horizontal vertical" ] ++ toMain;

        h = [ "focus left" ] ++ toMain;
        j = [ "focus down" ] ++ toMain;
        k = [ "focus up" ] ++ toMain;
        l = [ "focus right" ] ++ toMain;

        q = [ "workspace 1q" ] ++ toMain;
        w = [ "workspace 2w" ] ++ toMain;
        e = [ "workspace 3e" ] ++ toMain;
        r = [ "workspace 4r" ] ++ toMain;
        a = [ "workspace 5a" ] ++ toMain;
        s = [ "workspace 6s" ] ++ toMain;
        d = [ "workspace 7d" ] ++ toMain;
        f = [ "workspace 8f" ] ++ toMain;

        tab = [ "workspace-back-and-forth" ] ++ toMain;

      };

      mode.move.binding = {
        esc = toMain;

        enter = [ "move-workspace-to-monitor --wrap-around next" ] ++ toMain;

        up = "resize smart -50";
        down = "resize smart +50";

        q = [
          "move-node-to-workspace 1q"
          exec-twc
        ] ++ toMain;
        w = [
          "move-node-to-workspace 2w"
          exec-twc
        ] ++ toMain;
        e = [
          "move-node-to-workspace 3e"
          exec-twc
        ] ++ toMain;
        r = [
          "move-node-to-workspace 4r"
          exec-twc
        ] ++ toMain;
        a = [
          "move-node-to-workspace 5a"
          exec-twc
        ] ++ toMain;
        s = [
          "move-node-to-workspace 6s"
          exec-twc
        ] ++ toMain;
        d = [
          "move-node-to-workspace 7d"
          exec-twc
        ] ++ toMain;
        f = [
          "move-node-to-workspace 8f"
          exec-twc
        ] ++ toMain;

        h = [ "move left" ] ++ toMain;
        j = [ "move down" ] ++ toMain;
        k = [ "move up" ] ++ toMain;
        l = [ "move right" ] ++ toMain;

        shift-h = [ "join-with left" ] ++ toMain;
        shift-j = [ "join-with down" ] ++ toMain;
        shift-k = [ "join-with up" ] ++ toMain;
        shift-l = [ "join-with right" ] ++ toMain;
      };

      mode.service.binding = {
        esc = [ "reload-config" ] ++ toMain;
        r = [ "flatten-workspace-tree" ] ++ toMain;
        backspace = [ "close-all-windows-but-current" ] ++ toMain;
      };
    };
  };
}
