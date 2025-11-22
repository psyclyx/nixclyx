{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.psyclyx.system.fonts;
in
{
  options = {
    psyclyx.system.fonts = {
      enable = mkEnableOption "Configure fonts.";
    };
  };

  config = mkIf cfg.enable {
    fonts = {
      # font choice is handled in stylix

      fontconfig = {
        useEmbeddedBitmaps = true;
        hinting = {
          enable = true;
          autohint = true;
        };
      };
    };
  };
}
