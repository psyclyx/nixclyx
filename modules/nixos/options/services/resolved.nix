{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.nixos.services.resolved;
in {
  options = {
    psyclyx.nixos.services.resolved = {
      enable = lib.mkEnableOption "systemd-resolved dns resolver";
    };
  };

  config = lib.mkIf cfg.enable {
    services.resolved = {
      enable = true;
      settings.Resolve = {
        MulticastDNS = false;
      };
    };
  };
}
