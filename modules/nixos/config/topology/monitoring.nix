{
  config,
  lib,
  ...
}: let
  topo = config.psyclyx.topology;

  vpnHosts = lib.filterAttrs (_: host: host.vpn != null) topo.hosts;

  scrapeTargets = lib.mapAttrsToList
    (_: host: "${host.vpn.address}:9100")
    vpnHosts;
in {
  config = lib.mkIf config.psyclyx.nixos.services.prometheus.server.enable {
    psyclyx.nixos.services.prometheus.server.scrapeTargets = scrapeTargets;
  };
}
