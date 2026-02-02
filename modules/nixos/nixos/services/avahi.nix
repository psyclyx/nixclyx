{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.nixos.services.avahi;
in {
  options = {
    psyclyx.nixos.services.avahi = {
      enable = lib.mkEnableOption "Service discovery / MDNS";
    };
  };

  config = lib.mkIf cfg.enable {
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      publish.enable = true;
    };
  };
}
