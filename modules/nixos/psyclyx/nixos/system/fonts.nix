{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.nixos.system.fonts;
in
{
  options = {
    psyclyx.nixos.system.fonts = {
      enable = lib.mkEnableOption "Configure fonts.";
    };
  };

  config = lib.mkIf cfg.enable {
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
