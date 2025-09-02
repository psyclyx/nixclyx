{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.roles.graphical;
in
{
  options = {
    psyclyx.roles.graphical = {
      enable = lib.mkEnableOption "role for hosts intended to be used primarily through graphical sessions";
    };
  };

  config = lib.mkIf cfg.enable {
    psyclyx = {
      hardware = {
        qmk.enable = lib.mkDefault true;
      };
      programs = {
        sway.enable = lib.mkDefault true;
      };
      services = {
        autoMount.enable = lib.mkDefault true;
        gnome-keyring.enable = lib.mkDefault true;
        greetd.enable = lib.mkDefault true;
        printing.enable = lib.mkDefault true;
      };
      system = {
        fonts.enable = lib.mkDefault true;
      };
      stylix = {
        enable = lib.mkDefault true;
        baseFontSize = lib.mkDefault 16;
      };
    };
  };
}
