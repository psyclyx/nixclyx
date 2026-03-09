{
  path = ["psyclyx" "home" "programs" "fuzzel"];
  description = "Fuzzel application launcher";
  config = {config, ...}: {
    programs.fuzzel = {
      enable = true;
      settings = {
        main = {
          prompt = "\"  \"";
          placeholder = "\"Search...\"";
          icons-enabled = true;
          icon-theme = config.gtk.iconTheme.name or "hicolor";
          terminal = "xdg-terminal-exec";
          launch-prefix = "uwsm app --";
          layer = "overlay";
          lines = 8;
          width = 35;
          horizontal-pad = 16;
          vertical-pad = 12;
          inner-pad = 4;
          image-size-ratio = 0.5;
          line-height = 22;
          letter-spacing = 0.5;
          match-counter = true;
        };
        border = {
          width = 2;
          radius = 8;
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
