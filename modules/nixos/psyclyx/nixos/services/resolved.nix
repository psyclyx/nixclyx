{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.psyclyx.nixos.services.resolved;
in
{
  options = {
    psyclyx.nixos.services.resolved = {
      enable = mkEnableOption "systemd-resolved dns resolver";
    };
  };

  config = mkIf cfg.enable {
    services.resolved = {
      enable = true;
      extraConfig = ''
        MulticastDNS = off
      '';
    };
  };
}
