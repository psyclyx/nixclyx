{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.psyclyx.network.dns.client;
in
{
  options = {
    psyclyx.network.dns.client = {
      enable = mkEnableOption "avahi+systemd-resolved";
    };
  };

  config = mkIf cfg.enable {
    psyclyx.services = {
      avahi.enable = true;
      resolved.enable = true;
    };
  };
}
