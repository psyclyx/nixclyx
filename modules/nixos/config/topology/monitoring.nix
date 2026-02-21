{
  config,
  lib,
  ...
}: let
  topo = config.psyclyx.topology;

  vpnHosts = lib.filterAttrs (_: host: host.vpn != null) topo.hosts;
  labHosts = lib.filterAttrs (_: host: host.labIndex != null) topo.hosts;

  # VPN hosts excluding the hub (scraped by collector, not server).
  spokeVpnHosts = lib.filterAttrs (name: _: name != topo.vpn.hub) vpnHosts;

  spokeVpnTargets = lib.mapAttrsToList
    (name: _: "${name}.${topo.domain.internal}:9100")
    spokeVpnHosts;

  labTargets = lib.mapAttrsToList
    (name: _: "${name}.rack-vpn.${topo.conventions.homeDomain}:9100")
    labHosts;

  # SNMP targets: switches with a management address.
  snmpTargets = lib.concatLists (lib.mapAttrsToList (_: sw:
    lib.optional (sw ? mgmtAddress) sw.mgmtAddress
  ) topo.switches);

  hubVpnAddress = vpnHosts.${topo.vpn.hub}.vpn.address;
in {
  config = lib.mkMerge [
    (lib.mkIf config.psyclyx.nixos.services.prometheus.collector.enable {
      psyclyx.nixos.services.prometheus.collector = {
        scrapeTargets = spokeVpnTargets ++ labTargets;
        inherit snmpTargets;
        remoteWriteUrl = lib.mkDefault "http://${hubVpnAddress}:9090/api/v1/write";
      };
    })
    (lib.mkIf config.psyclyx.nixos.services.prometheus.server.enable {
      # Server only scrapes itself (localhost:9100 is added automatically).
      # All other targets are scraped by the collector and remote-written.
    })
  ];
}
