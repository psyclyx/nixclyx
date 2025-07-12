{ ... }:
let
  c = import ../../colors.nix;
in
{
  wayland.windowManager.sway = {
    config = {
      colors = {
        focused = {
          background = c.base-light;
          text = c.fg;
          border = c.base;
          childBorder = c.base-light;
          indicator = c.accent;
        };

        focusedInactive = {
          background = c.base;
          text = c.fg;
          border = c.base;
          childBorder = c.base;
          indicator = c.accent;
        };

        unfocused = {
          background = c.base-dark;
          text = c.fg-dark;
          border = c.base-dark;
          childBorder = c.base-dark;
          indicator = c.accent;
        };

        urgent = {
          background = c.red3;
          text = c.fg;
          border = c.red3;
          childBorder = c.red3;
          indicator = c.accent;
        };
      };

      fonts = {
        names = [ "Aporetic Sans" ];
        size = 14.0;
      };

      window = {
        border = 2;
      };
    };

    extraConfig = ''
      output * scale 1
      output * bg ${c.bg} solid_color
      titlebar_border_thickness 0
      titlebar_padding 4 0
    '';
  };
}
