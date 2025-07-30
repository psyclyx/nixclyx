{ pkgs, ... }:
{
  stylix = {
    enable = true;
    image = ./wallpapers/madoka-homura-2x.png;
    opacity = {
      applications = 0.9;
      desktop = 0.8;
      terminal = 0.9;
      popups = 0.8;
    };
    fonts = {
      sizes = {
        desktop = 12;
        applications = 14;
        terminal = 14;
        popups = 14;
      };
      serif = {
        package = pkgs.nerd-fonts.noto;
        name = "NotoSerif Nerd Font";
      };
      sansSerif = {
        package = pkgs.nerd-fonts.noto;
        name = "NotoSans Nerd Font";
      };
      monospace = {
        package = pkgs.aporetic;
        name = "Aporetic Sans Mono";
      };
      emoji = {
        package = pkgs.noto-fonts-emoji;
        name = "Noto Color Emoji";
      };
    };
  };
}
