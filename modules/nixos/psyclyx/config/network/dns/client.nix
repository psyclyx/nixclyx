{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.network.dns.client;
in
{
  options = {
    psyclyx.network.dns.client = {
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
