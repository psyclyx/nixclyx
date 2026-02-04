{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.nixos.network.dns.client;
in {
  options = {
    psyclyx.nixos.network.dns.client = {
      enable = lib.mkEnableOption "avahi+systemd-resolved";
    };
  };

  config = lib.mkIf cfg.enable {
    psyclyx.nixos.services = {
      avahi.enable = true;
      resolved.enable = true;
    };
  };
}
