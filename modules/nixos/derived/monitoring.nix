{ config, lib, ... }:
let
  eg = config.psyclyx.egregore;

  # The one `exposures` aspect (Phase 6 merged its two homes), kept as
  # a local spelling beside exportersOf.
  exposuresOf = e: e.exposures or { };
  exportersOf = e: lib.filterAttrs (_: x: (x.role or null) == "exporter") (exposuresOf e);

  mkTarget =
    hostName: svc:
    let
      net = builtins.head svc.scopes;
      fqdn = eg.entities.${hostName}.fqdns.${net} or null;
    in
    if fqdn != null then "${fqdn}:${toString svc.port}" else null;

  monitoredHosts = lib.filterAttrs (
    _: e: e.type == "host" && exportersOf e != { }
  ) eg.entities;

  hubName = eg.entities.vpn.gatewayRef;
  spokeHosts = lib.filterAttrs (name: _: name != hubName) monitoredHosts;

  collectTargets =
    hosts:
    lib.concatLists (
      lib.mapAttrsToList (
        hostName: e:
        lib.mapAttrsToList (svcName: svc: {
          inherit svcName;
          target = mkTarget hostName svc;
        }) (exportersOf e)
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
    exportersOf monitoredHosts.${hubName}
  );

  hubExtraScrapeConfigs = lib.mapAttrsToList (svcName: svc: {
    job_name = svcName;
    static_configs = [ { targets = [ "localhost:${toString svc.port}" ]; } ];
  }) hubExporters;

  # For each exporter exposure on THIS host, set its listenAddress to
  # the host's IPv4 on the exposure's first scope (typically the
  # vpn overlay, so prom only scrapes over WG). Skips exporters whose
  # scope isn't in the host's addresses map (e.g. exporters with
  # scopes = ["infra"] on a host without infra).
  myName = config.psyclyx.nixos.host;
  meEntity = eg.entities.${myName} or null;
  myExporters = if meEntity == null then { } else exportersOf meEntity;
  exporterListenAddrs = lib.mapAttrs (_: svc:
    let net = builtins.head svc.scopes;
        addr = (meEntity.addresses.${net} or {}).ipv4 or null;
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
