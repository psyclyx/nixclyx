{
  config,
  lib,
  ...
}: let
  topo = config.psyclyx.topology;

  wgHosts = lib.filterAttrs (_: host: host.wireguard != null) topo.hosts;
  labHosts = lib.filterAttrs (_: host: host.labIndex != null) topo.hosts;

  # WireGuard hosts excluding the hub (scraped by collector, not server).
  spokeWgHosts = lib.filterAttrs (name: _: name != topo.wireguard.hub) wgHosts;

  spokeWgTargets = lib.mapAttrsToList
    (name: _: "${name}.${topo.domains.internal}:9100")
    spokeWgHosts;

  labTargets = lib.mapAttrsToList
    (name: _: "${name}.rack.${topo.domains.home}:9100")
    labHosts;

  mkLabTargets = port: lib.mapAttrsToList
    (name: _: "${name}.rack.${topo.domains.home}:${toString port}")
    labHosts;

  redisTargets = mkLabTargets 9121;
  postgresTargets = mkLabTargets 9187;
  juicefsTargets = mkLabTargets 9567;

  smartctlSpokeWgTargets = lib.mapAttrsToList
    (name: _: "${name}.${topo.domains.internal}:9633")
    spokeWgHosts;

  smartctlLabTargets = mkLabTargets 9633;

  # SNMP targets: switches with a management address.
  snmpTargets = lib.concatLists (lib.mapAttrsToList (_: sw:
    lib.optional (sw.mgmt != null) sw.mgmt.ipv4
  ) topo.switches);

  hubVpnAddress = wgHosts.${topo.wireguard.hub}.addresses.vpn.ipv4;
in {
  config = lib.mkMerge [
    (lib.mkIf config.psyclyx.nixos.services.prometheus.collector.enable {
      psyclyx.nixos.services.prometheus.collector = {
        scrapeTargets = spokeWgTargets ++ labTargets;
        inherit snmpTargets;
        remoteWriteUrl = lib.mkDefault "http://${hubVpnAddress}:9090/api/v1/write";
        extraScrapeConfigs = [
          {
            job_name = "redis";
            static_configs = [{targets = redisTargets;}];
          }
          {
            job_name = "postgres";
            static_configs = [{targets = postgresTargets;}];
          }
          {
            job_name = "juicefs";
            static_configs = [{targets = juicefsTargets;}];
          }
          {
            job_name = "smartctl";
            static_configs = [{targets = smartctlSpokeWgTargets ++ smartctlLabTargets;}];
          }
        ];
      };
    })
    (lib.mkIf config.psyclyx.nixos.services.prometheus.server.enable {
      # Server only scrapes itself (localhost:9100 is added automatically).
      # All other targets are scraped by the collector and remote-written.
      psyclyx.nixos.services.prometheus.server.extraScrapeConfigs = [
        {
          job_name = "smartctl";
          static_configs = [{targets = ["localhost:9633"];}];
        }
      ];
    })
  ];
}
