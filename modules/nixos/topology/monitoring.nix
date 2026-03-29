{config, lib, ...}: let
  eg = config.psyclyx.egregore;

  resolveAddress = hostName: network:
    if network == "vpn"
    then "${hostName}.${eg.domains.internal}"
    else "${hostName}.${network}.${eg.domains.home}";

  mkTarget = hostName: svc:
    "${resolveAddress hostName (builtins.head svc.networks)}:${toString svc.port}";

  monitoredHosts = lib.filterAttrs (_: e:
    e.type == "host" && e.host.exporters != {}
  ) eg.entities;

  spokeHosts = lib.filterAttrs (name: _: name != eg.overlay.hub) monitoredHosts;

  collectTargets = hosts:
    lib.concatLists (lib.mapAttrsToList (hostName: e:
      lib.mapAttrsToList (svcName: svc: {
        inherit svcName;
        target = mkTarget hostName svc;
      }) e.host.exporters
    ) hosts);

  spokeTargetPairs = collectTargets spokeHosts;
  targetsByService = builtins.groupBy (t: t.svcName) spokeTargetPairs;

  nodeTargets = map (t: t.target) (targetsByService.node or []);
  extraServices = lib.filterAttrs (name: _: name != "node") targetsByService;

  extraScrapeConfigs = lib.mapAttrsToList (svcName: targets: {
    job_name = svcName;
    static_configs = [{targets = map (t: t.target) targets;}];
  }) extraServices;

  hubVpnAddress = monitoredHosts.${eg.overlay.hub}.host.addresses.vpn.ipv4;

  hubExporters = lib.filterAttrs (name: _: name != "node")
    (monitoredHosts.${eg.overlay.hub}.host.exporters or {});

  hubExtraScrapeConfigs = lib.mapAttrsToList (svcName: svc: {
    job_name = svcName;
    static_configs = [{targets = ["localhost:${toString svc.port}"];}];
  }) hubExporters;
in {
  config = lib.mkMerge [
    (lib.mkIf config.psyclyx.nixos.services.prometheus.collector.enable {
      psyclyx.nixos.services.prometheus.collector = {
        scrapeTargets = nodeTargets;
        inherit extraScrapeConfigs;
        remoteWriteUrl = lib.mkDefault "http://${hubVpnAddress}:9090/api/v1/write";
      };
    })
    (lib.mkIf config.psyclyx.nixos.services.prometheus.server.enable {
      psyclyx.nixos.services.prometheus.server.extraScrapeConfigs = hubExtraScrapeConfigs;
    })
  ];
}
