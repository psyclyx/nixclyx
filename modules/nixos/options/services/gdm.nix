{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.nixos.services.gdm;
in {
  options = {
    psyclyx.nixos.services.gdm = {
      enable = lib.mkEnableOption "GNOME DIsplay Manager";
    };
  };

  config = lib.mkIf cfg.enable {
    services.displayManager.gdm = {
      enable = true;
    };
  };
}
