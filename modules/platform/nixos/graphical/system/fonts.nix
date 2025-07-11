{ pkgs, ... }:
{
  fonts = {
    packages = with pkgs; [
      aporetic
      nerd-fonts.noto
      nerd-fonts.fira-code
      font-awesome
      lato
      liberation_ttf
      open-sans
      roboto
      ubuntu_font_family
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
