{ config, lib, ... }:
let
  cfg = config.psyclyx.programs.kitty;
in
{
  options = {
    psyclyx.programs.kitty = {
      enable = lib.mkEnableOption "Kitty terminal emulator";
    };
  };

  config = lib.mkIf cfg.enable {
    programs = {
      kitty = {
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
    };
  };
}
