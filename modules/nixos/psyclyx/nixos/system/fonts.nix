{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.psyclyx.nixos.system.fonts;
in
{
  options = {
    psyclyx.nixos.system.fonts = {
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
