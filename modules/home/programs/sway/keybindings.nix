{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) getExe getExe' concatMapAttrs;

  # Applications
  menus = import ./menus.nix { inherit config pkgs lib; };

  launcher = "fuzzel";
  power-menu = getExe menus.power-menu;
  screenshot-menu = getExe menus.screenshot-menu;

  browser = "firefox";
  terminal = "alacritty";
  editor = "emacsclient";
  editorAlt = "emacs";

  backlightUp = "light -U 10";
  backlightDown = "light -D 10";
  volumeUp = "pactl set-sink-volume '@DEFAULT_SINK@' '+5%'";
  volumeDown = "pactl set-sink-volume '@DEFAULT_SINK@' '-5%'";
  volumeMute = "pactl set-sink-mute '@DEFAULT_SINK@' toggle";

  # Keys
  leaderKey = "Super";
  directionKeys = {
    left = "h";
    down = "j";
    up = "k";
    right = "l";
  };
  moveKey = "Shift";
  fineKey = "Ctrl";
  coarseKey = "Super";
  resizeModeKey = "r";
  exitModeKey = "Escape";
  workspaceKeys = lib.listToAttrs (
    lib.imap1 (i: key: {
      name = "workspace number ${builtins.toString i}";
      value = builtins.toString key;
    }) (lib.range 1 9 ++ [ 0 ])
  );

  # Configuration
  steps = {
    fine = "1 ppt or 10px";
    default = "5 ppt or 50px";
    coarse = "25 ppt or 250px";
  };

  resizeKeys = with directionKeys; {
    "shrink width" = left;
    "grow height" = down;
    "shrink height" = up;
    "grow width" = right;
  };

  # Binds
  directionBinds = concatMapAttrs (direction: key: {
    "${leaderKey}+${key}" = "focus ${direction}";
    "${leaderKey}+${moveKey}+${key}" = "move ${direction} ${steps.default}";
  }) directionKeys;

  workspaceBinds = lib.concatMapAttrs (workspace: key: {
    "${leaderKey}+${key}" = workspace;
    "${leaderKey}+${moveKey}+${key}" = "move container to ${workspace}";
  }) workspaceKeys;

  layoutBinds = {
    "${leaderKey}+semicolon" = "focus mode_toggle";
    "${leaderKey}+Shift+semicolon" = "floating toggle";

    "${leaderKey}+n" = "focus parent";
    "${leaderKey}+Shift+n" = "focus child";

    "${leaderKey}+comma" = "layout toggle stacking tabbed";
    "${leaderKey}+Shift+comma" = "layout toggle split";

    "${leaderKey}+period" = "splitt";
    "${leaderKey}+Shift+period" = "split none";

    "${leaderKey}+slash" = "fullscreen toggle";
  };

  modeBinds = {
    "${leaderKey}+${resizeModeKey}" = "mode resize";
  };

  applicationBinds = {
    "${leaderKey}+Return" = "exec ${launcher}";
    "${leaderKey}+x" = "exec ${power-menu}";

    "${leaderKey}+s" = "exec ${screenshot-menu}";

    "${leaderKey}+u" = "exec ${browser}";
    "${leaderKey}+i" = "exec ${terminal}";
    "${leaderKey}+o" = "exec ${editor} -cn -a ''";
    "${leaderKey}+Shift+o" = "exec ${editorAlt}";
  };

  backlightBinds = {
    "XF86MonBrightnessUp" = "exec ${backlightUp}";
    "XF86MonBrightnessDown" = "exec ${backlightDown}";
  };

  mediaBinds = {
    "XF86AudioRaiseVolume" = "exec ${volumeUp}";
    "XF86AudioLowerVolume" = "exec ${volumeDown}";
    "XF86AudioMute" = "exec ${volumeMute}";
  };

  controlBinds = {
    "${leaderKey}+Shift+q" = "kill";
    "${leaderKey}+Shift+c" = "reload";
  };

  ## Resize mode
  resizeBinds = lib.concatMapAttrs (
    direction: key: with steps; {
      "${fineKey}+${key}" = "resize ${direction} ${fine}";
      "${key}" = "resize ${direction} ${default}";
      "${coarseKey}+${key}" = "resize ${direction} ${coarse}";
    }
  ) resizeKeys;

  moveBinds = lib.concatMapAttrs (
    direction: key: with steps; {
      "${moveKey}+${fineKey}+${key}" = "move ${direction} ${fine}";
      "${moveKey}+${key}" = "move ${direction} ${default}";
      "${moveKey}+${coarseKey}+${key}" = "move ${direction} ${coarse}";
    }
  ) directionKeys;

  # Merged keybindings
  keybindings =
    directionBinds
    // workspaceBinds
    // layoutBinds
    // modeBinds
    // applicationBinds
    // backlightBinds
    // mediaBinds
    // controlBinds;

  resizeModeKeybindings = resizeBinds // moveBinds // { "${exitModeKey}" = "mode default"; };

  modes = {
    resize = resizeModeKeybindings;
  };
in
{
  wayland.windowManager.sway.config = {
    inherit keybindings modes;
  };
}
