{
  config,
  lib,
  ...
}: let
  topo = config.psyclyx.topology;

  # Resolve a host's scrape address based on its exporter's network.
  # "vpn" → internal domain FQDN; any physical network → network.home FQDN.
  resolveAddress = hostName: network:
    if network == "vpn"
    then "${hostName}.${topo.domains.internal}"
    else "${hostName}.${network}.${topo.domains.home}";

  # Build a target string from a host's exporter entry.
  # Uses the first declared network for address resolution.
  mkTarget = hostName: svc:
    "${resolveAddress hostName (builtins.head svc.networks)}:${toString svc.port}";

  # Hosts participating in monitoring (have at least one exporter declared).
  monitoredHosts = lib.filterAttrs (_: host: host.exporters != {}) topo.hosts;

  # All monitored hosts except the WireGuard hub (hub is scraped by the server, not collector).
  spokeHosts = lib.filterAttrs (name: _: name != topo.wireguard.hub) monitoredHosts;

  # Collect all (serviceName, target) pairs from a set of hosts.
  collectTargets = hosts:
    lib.concatLists (lib.mapAttrsToList (hostName: host:
      lib.mapAttrsToList (svcName: svc: {
        inherit svcName;
        target = mkTarget hostName svc;
      }) host.exporters
    ) hosts);

  spokeTargetPairs = collectTargets spokeHosts;

  # Group targets by service name.
  targetsByService = builtins.groupBy (t: t.svcName) spokeTargetPairs;

  # Extract the "node" targets for scrapeTargets, everything else for extraScrapeConfigs.
  nodeTargets = map (t: t.target) (targetsByService.node or []);
  extraServices = lib.filterAttrs (name: _: name != "node") targetsByService;

  extraScrapeConfigs = lib.mapAttrsToList (svcName: targets: {
    job_name = svcName;
    static_configs = [{targets = map (t: t.target) targets;}];
  }) extraServices;

  hubVpnAddress = monitoredHosts.${topo.wireguard.hub}.addresses.vpn.ipv4;

  # Hub host's own exporters (for server self-scrape), excluding "node" (auto-added).
  hubExporters = lib.filterAttrs (name: _: name != "node")
    (monitoredHosts.${topo.wireguard.hub}.exporters or {});

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
