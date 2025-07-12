{ config, lib, ... }:
let
  cfg = config.psyclyx.programs.alacritty;
  font = {
    normal = {
      family = "Aporetic Sans Mono";
    };
    size = 16;
  };
  doomOne = {
    primary = {
      background = "0x282c34";
      foreground = "0xbbc2cf";
    };
    normal = {
      black = "0x282c34";
      red = "0xff6c6b";
      green = "0x98be65";
      yellow = "0xecbe7b";
      blue = "0x51afef";
      magenta = "0xc678dd";
      cyan = "0x46d9ff";
      white = "0xbbc2cf";
    };
  };
  colors = doomOne;
in
{
  options = {
    psyclyx = {
      programs = {
        alacritty = {
          enable = lib.mkEnableOption "Configure alacritty.";
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    programs = {
      alacritty = {
        enable = true;
        settings = {
          window = {
            option_as_alt = "Both";
          };
          inherit font colors;
        };
      };
    };
  };
}
