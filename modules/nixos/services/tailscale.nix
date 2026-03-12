{
  path = ["psyclyx" "nixos" "services" "tailscale"];
  description = "Enable tailscale service and related settings";
  options = {lib, ...}: {
    exitNode = lib.mkEnableOption "Configure tailscale client as an exit node";
  };
  config = {
    cfg,
    config,
    pkgs,
    ...
  }: let
    tsCfg = config.services.tailscale;
  in {
    environment.systemPackages = [pkgs.tailscale];
    psyclyx.nixos.network = {
      firewall = {
        zones.tailscale.interfaces = [tsCfg.interfaceName];
        input.tailscale.policy = "accept";
      };
      ports.tailscale = {udp = [tsCfg.port];};
    };
    services.tailscale = {
      enable = true;
      useRoutingFeatures =
        if cfg.exitNode
        then "both"
        else "client";
    };

    systemd.network.wait-online.ignoredInterfaces = [tsCfg.interfaceName];
  };
}
