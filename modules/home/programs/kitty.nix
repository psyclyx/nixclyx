{ ... }:
{
  programs.kitty = {
    enable = true;
    settings = {
      enable_audio_bell = false;
    };
    themeFile = "Doom_One";
    font = {
      size = 14;
      name = "Aporetic Sans Mono";
    };
  };
}
