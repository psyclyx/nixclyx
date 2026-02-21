{
  config,
  lib,
  ...
}: let
  topo = config.psyclyx.topology;

  vpnHosts = lib.filterAttrs (_: host: host.vpn != null) topo.hosts;
  labHosts = lib.filterAttrs (_: host: host ? labIndex) topo.hosts;

  vpnTargets = lib.mapAttrsToList
    (name: _: "${name}.${topo.domain.internal}:9100")
    vpnHosts;

  labTargets = lib.mapAttrsToList
    (name: _: "${name}.rack-vpn.${topo.conventions.homeDomain}:9100")
    labHosts;

  scrapeTargets = vpnTargets ++ labTargets;
in {
  config = lib.mkIf config.psyclyx.nixos.services.prometheus.server.enable {
    psyclyx.nixos.services.prometheus.server.scrapeTargets = scrapeTargets;
  };
}
