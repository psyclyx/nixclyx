{ config, lib, ... }:
let
  cfg = config.psyclyx.services.resolved;
in
{
  options = {
    psyclyx.services.resolved = {
      enable = lib.mkEnableOption "systemd-resolved dns resolver";
    };
  };

  config = lib.mkIf cfg.enable {
    services.resolved.enable = true;
  };
}
