{ config, lib, ... }:
let
  cfg = config.psyclyx.nixos.services.gnome-keyring;
  greetdCfg = config.psyclyx.nixos.services.greetd;
in
{
  options = {
    psyclyx.nixos.services.gnome-keyring = {
      enable = lib.mkEnableOption "gnome-keyring";
    };
  };

  config = lib.mkIf cfg.enable {
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.greetd.enableGnomeKeyring = lib.mkIf greetdCfg.enable true;
  };
}
