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
        dejavu_fonts
        font-awesome
        liberation_ttf
        nerd-fonts.noto
        nerd-fonts.symbols-only
        twitter-color-emoji
        ubuntu_font_family
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
