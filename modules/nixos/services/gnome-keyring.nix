{ config, lib, ... }:
let
  cfg = config.psyclyx.services.gnome-keyring;
  greetdCfg = config.psyclyx.services.greetd;
in
{
  options = {
    psyclyx.services.gnome-keyring.enable = lib.mkEnableOption "gnome-keyring";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.gnome.gnome-keyring.enable = true;
    })
    (lib.mkIf greetdCfg.enable {
      security.pam.services.greetd.enableGnomeKeyring = true;
    })
  ];
}
