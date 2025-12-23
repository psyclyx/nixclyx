{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.psyclyx.nixos.services.tailscale;
  tsCfg = config.services.tailscale;
in
{
  options = {
    psyclyx.nixos.services.tailscale = {
      enable = mkEnableOption "Enable tailscale service and related settings";
      exitNode = mkEnableOption "Configure tailscale client as an exit node";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.tailscale ];
    networking.firewall.trustedInterfaces = [ tsCfg.interfaceName ];
    services.tailscale = {
      enable = true;
      openFirewall = true;
      useRoutingFeatures = if cfg.exitNode then "both" else "client";
    };

    systemd.network.wait-online.ignoredInterfaces = [ tsCfg.interfaceName ];
  };
}
