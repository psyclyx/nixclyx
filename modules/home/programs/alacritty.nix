{ config, lib, ... }:
let
  cfg = config.psyclyx.programs.alacritty;
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
        };
      };
    };
  };
}
