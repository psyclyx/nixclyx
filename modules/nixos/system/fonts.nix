{
  path = ["psyclyx" "nixos" "system" "fonts"];
  description = "Configure fonts.";
  config = _: {
    fonts = {
      fontconfig = {
        useEmbeddedBitmaps = true;
        hinting = {
          enable = true;
          autohint = true;
        };
      };
    };
  };
}
