{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.psyclyx.system.fonts;
in
{
  options = {
    psyclyx = {
      system = {
        fonts = {
          enable = lib.mkEnableOption "Configure fonts.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    fonts = {
      packages = with pkgs; [
        aporetic
        font-awesome
        liberation_ttf
        nerd-fonts.noto
        ubuntu_font_family
        twitter-color-emoji
      ];
      fontconfig = {
        useEmbeddedBitmaps = true;
        defaultFonts = {
          monospace = [ "Aporetic Sans Mono" ];
          serif = [ "Aporetic Serif" ];
          sansSerif = [ "Aporetic Sans" ];
          emoji = [ "Twitter Color Emoji" ];
        };
      };
    };
  };
}
