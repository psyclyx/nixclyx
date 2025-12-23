{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf mkMerge;
  cfg = config.psyclyx.nixos.services.gnome-keyring;
  greetdCfg = config.psyclyx.nixos.services.greetd;
in
{
  options = {
    psyclyx.nixos.services.gnome-keyring = {
      enable = mkEnableOption "gnome-keyring";
    };
  };

  config = mkIf cfg.enable {
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.greetd.enableGnomeKeyring = mkIf greetdCfg.enable true;
  };
}
