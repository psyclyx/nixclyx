{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.psyclyx.graphics.fonts;
in
{
  options = {
    psyclyx = {
      graphics = {
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
        defaultFonts = {
          monospace = [ "NotoMono Nerd Font" ];
          serif = [ "NotoSerif Nerd Font" ];
          sansSerif = [ "NotoSans Nerd Font" ];
          emoji = [ "Twitter Color Emoji" ];
        };
      };
    };
  };
}
