{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.psyclyx.nixos.services.avahi;
in
{
  options = {
    psyclyx.nixos.services.avahi = {
      enable = mkEnableOption "Service discovery / MDNS";
    };
  };

  config = mkIf cfg.enable {
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      publish.enable = true;
    };
  };
}
