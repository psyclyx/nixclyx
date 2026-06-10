{ config, lib, ... }:
let
  eg = config.psyclyx.egregore;

  mkTarget =
    hostName: svc:
    let
      net = builtins.head svc.networks;
      fqdn = eg.entities.${hostName}.attrs.fqdns.${net} or null;
    in
    if fqdn != null then "${fqdn}:${toString svc.port}" else null;

  monitoredHosts = lib.filterAttrs (
    _: e: e.type == "host" && e.attrs.resolvedExporters != { }
  ) eg.entities;

  hubName = eg.entities.vpn.attrs.gatewayRef;
  spokeHosts = lib.filterAttrs (name: _: name != hubName) monitoredHosts;

  collectTargets =
    hosts:
    lib.concatLists (
      lib.mapAttrsToList (
        hostName: e:
        lib.mapAttrsToList (svcName: svc: {
          inherit svcName;
          target = mkTarget hostName svc;
        }) e.attrs.resolvedExporters
      ) hosts
    );

  spokeTargetPairs = lib.filter (t: t.target != null) (collectTargets spokeHosts);
  targetsByService = builtins.groupBy (t: t.svcName) spokeTargetPairs;

  nodeTargets = map (t: t.target) (targetsByService.node or [ ]);
  extraServices = lib.filterAttrs (name: _: name != "node") targetsByService;

  extraScrapeConfigs = lib.mapAttrsToList (svcName: targets: {
    job_name = svcName;
    static_configs = [ { targets = map (t: t.target) targets; } ];
  }) extraServices;

  hubVpnAddress = monitoredHosts.${hubName}.host.addresses.vpn.ipv4;

  hubExporters = lib.filterAttrs (name: _: name != "node") (
    monitoredHosts.${hubName}.attrs.resolvedExporters or { }
  );

  hubExtraScrapeConfigs = lib.mapAttrsToList (svcName: svc: {
    job_name = svcName;
    static_configs = [ { targets = [ "localhost:${toString svc.port}" ]; } ];
  }) hubExporters;

  # For each exporter declared on THIS host, set its listenAddress to
  # the host's IPv4 on the exporter's first network (typically the
  # vpn overlay, so prom only scrapes over WG). Skips exporters whose
  # network isn't in the host's addresses map (e.g. exporters with
  # networks=["infra"] on a host without infra).
  myName = config.psyclyx.nixos.host;
  meEntity = eg.entities.${myName} or null;
  myExporters = if meEntity == null then {} else meEntity.attrs.resolvedExporters or {};
  exporterListenAddrs = lib.mapAttrs (_: svc:
    let net = builtins.head svc.networks;
        addr = (meEntity.attrs.addresses.${net} or {}).ipv4 or null;
    in addr
  ) myExporters;
in
{
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
    {
      services.prometheus.exporters = lib.mapAttrs (_: addr: {
        listenAddress = lib.mkDefault addr;
      }) (lib.filterAttrs (_: addr: addr != null) exporterListenAddrs);
    }
  ];
}
