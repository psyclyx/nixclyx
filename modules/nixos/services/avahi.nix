{ config, lib, ... }:
let
  cfg = config.psyclyx.services.avahi;
in
{
  options = {
    psyclyx.services.avahi = {
      enable = lib.mkEnableOption "Service discovery / mdns";
    };
  };

  config = lib.mkIf cfg.enable {
    services.avahi = {
      enable = true;
      nssmdns = true;
      openFirewall = true;
    };
  };
}
