{
  path = ["psyclyx" "nixos" "services" "gnome-keyring"];
  description = "gnome-keyring";
  config = {
    config,
    lib,
    ...
  }: let
    greetdCfg = config.psyclyx.nixos.services.greetd;
  in {
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.greetd.enableGnomeKeyring = lib.mkIf greetdCfg.enable true;
  };
}
