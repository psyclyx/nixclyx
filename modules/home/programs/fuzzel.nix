{
  path = ["psyclyx" "home" "programs" "fuzzel"];
  description = "Fuzzel application launcher";
  config = {config, lib, ...}: let
    c = config.lib.stylix.colors;
    opacity = builtins.substring 0 2 (lib.toHexString (builtins.floor (config.stylix.opacity.popups * 255)));
  in {
    programs.fuzzel = {
      enable = true;
      settings = {
        main = {
          font = lib.mkForce "${config.stylix.fonts.monospace.name}:size=${toString config.stylix.fonts.sizes.desktop}";
          prompt = "\"  \"";
          placeholder = "\"...\"";
          icons-enabled = true;
          icon-theme = config.gtk.iconTheme.name or "hicolor";
          terminal = "xdg-terminal-exec";
          launch-prefix = "uwsm app --";
          layer = "overlay";
          lines = 10;
          width = 50;
          message-mode = "wrap";
          horizontal-pad = 20;
          vertical-pad = 16;
          inner-pad = 6;
          image-size-ratio = 0.5;
          line-height = 22;
          letter-spacing = 0.5;
          match-counter = true;
        };
        colors = {
          # Muted prompt so it doesn't compete with input text
          prompt = lib.mkForce "${c.base04}ff";
          counter = lib.mkForce "${c.base04}ff";
          placeholder = lib.mkForce "${c.base03}ff";
        };
        border = {
          width = 2;
          radius = 12;
        };
        dmenu.exit-immediately-if-empty = true;
        key-bindings = {
          cancel = "Escape Control+c";
          delete-line = "Control+u";
          delete-prev-word = "Control+w";
        };
      };
    };
  };
}
