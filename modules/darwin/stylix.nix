{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.psyclyx.stylix;
in
{
  imports = [ inputs.stylix.darwinModules.stylix ];

  options = {
    psyclyx.stylix = {
      enable = lib.mkEnableOption "stylix theming";
      image = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "path to wallpaper";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    stylix = {
      enable = true;
      image = lib.mkIf (cfg.image != null) cfg.image;
    };
  };
}
