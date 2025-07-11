{ lib, pkgs, ... }:
let
  colors = import ../../../home/themes/angel.nix { inherit lib; };
  theme =
    with colors.colorUtils;
    mkTheme [
      (transform.withAlpha 0.9)
      transform.withOx
    ];
in
{
  services.jankyborders = {
    enable = false;
    package = pkgs.jankyborders;

    active_color = theme.wm.focused.border;
    inactive_color = theme.wm.unfocused.border;

    width = 2.0;
  };
}
