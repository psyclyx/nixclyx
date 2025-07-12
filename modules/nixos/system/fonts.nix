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
        nerd-fonts.noto
        liberation_ttf
        twitter-color-emoji
      ];
      fontconfig = {
        useEmbeddedBitmaps = true;
        defaultFonts = {
          monospace = [ "Aporetic Serif Mono" ];
          serif = [ "Aporetic Serif" ];
          sansSerif = [ "Aporetic Sans" ];
          emoji = [ "Twitter Color Emoji" ];
        };
      };
    };
  };
}
