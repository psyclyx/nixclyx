{nixclyx, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "system" "fonts"];
  description = "Configure fonts.";
  config = _: {
    fonts = {
      # font choice is handled in stylix
      fontconfig = {
        useEmbeddedBitmaps = true;
        hinting = {
          enable = true;
          autohint = true;
        };
      };
    };
  };
} args
