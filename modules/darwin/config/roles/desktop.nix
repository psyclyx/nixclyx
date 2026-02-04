{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.darwin.config.roles.desktop;
in {
  options.psyclyx.darwin.config.roles.desktop = {
    enable = lib.mkEnableOption "desktop darwin role";
  };

  config = lib.mkIf cfg.enable {
    psyclyx.darwin = {
      programs = {
        firefox.enable = lib.mkDefault true;
        raycast.enable = lib.mkDefault true;
      };
      services = {
        aerospace.enable = lib.mkDefault true;
        sketchybar.enable = lib.mkDefault true;
      };
    };
  };
}
