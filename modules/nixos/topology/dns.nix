{
  config,
  lib,
  ...
}: let
  topo = config.psyclyx.topology;

  vpnHosts = lib.filterAttrs (_: host: host.vpn != null) topo.hosts;

  dnsRecords = lib.concatLists (lib.mapAttrsToList (name: host: [
      "${name}.${topo.domain.internal}. IN A ${host.vpn.address}"
    ])
    vpnHosts);
in {
  config = lib.mkIf config.psyclyx.nixos.network.dns.resolver.enable {
    psyclyx.nixos.network.dns.resolver.localZones.${topo.domain.internal} = {
      type = lib.mkDefault "transparent";
      records = dnsRecords;
    };
  };
}
