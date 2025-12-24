{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf;
  cfg = config.psyclyx.home.programs.sway;
in
{
  config = mkIf cfg.enable {
    programs.swaylock = {
      enable = true;
      package = pkgs.swaylock-effects;
      settings = {
        indicator = true;
        screenshots = true;
        clock = true;
        show-failed-attempts = true;
        indicator-radius = 280;
        indicator-thickness = 4;
        effect-pixelate = 8;
        grace = 3;
      };
    };
  };
}
