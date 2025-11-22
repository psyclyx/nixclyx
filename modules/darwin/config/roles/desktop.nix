{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.roles.desktop;
in
{
  options = {
    psyclyx.roles.desktop = {
      enable = lib.mkEnableOption "role for desktop/graphical darwin hosts";
    };
  };

  config = lib.mkIf cfg.enable {
    psyclyx = {
      programs = {
        firefox.enable = lib.mkDefault true;
        raycast.enable = lib.mkDefault true;
      };
      services = {
        aerospace.enable = lib.mkDefault true;
        sketchybar.enable = lib.mkDefault true;
      };
      stylix = {
        enable = lib.mkDefault true;
      };
    };
  };
}
