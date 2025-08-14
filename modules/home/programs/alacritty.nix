{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.programs.alacritty;
in
{
  options.psyclyx.programs.alacritty.enable = lib.mkEnableOption "alacritty";

  config = lib.mkIf cfg.enable {

    programs.alacritty = {
      enable = true;
      package = pkgs.alacritty-graphics;
      settings = {
        window = {
          option_as_alt = "Both";
        };
      };
    };
  };
}
