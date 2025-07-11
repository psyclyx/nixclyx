{ config, lib, ... }:
let
  cfg = config.psyclyx.services.gnome-keyring;
in
{
  options = {
    psyclyx = {
      services = {
        gnome-keyring = {
          enable = lib.mkEnableOption "Enable gnome-keyring.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services = {
      gnome = {
        gnome-keyring = {
          enable = true;
        };
      };
    };
  };
}
