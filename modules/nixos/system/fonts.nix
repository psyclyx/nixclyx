{ pkgs, ... }:
{
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
}
