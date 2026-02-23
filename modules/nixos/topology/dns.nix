{
  config,
  lib,
  ...
}: let
  topo = config.psyclyx.topology;

  wgHosts = lib.filterAttrs (_: host: host.wireguard != null) topo.hosts;

  dnsRecords = lib.concatLists (lib.mapAttrsToList (name: host: [
      "${name}.${topo.domains.internal}. IN A ${host.addresses.vpn.ipv4}"
    ])
    wgHosts);
in {
  config = lib.mkIf config.psyclyx.nixos.network.dns.resolver.enable {
    psyclyx.nixos.network.dns.resolver.localZones.${topo.domains.internal} = {
      type = lib.mkDefault "transparent";
      records = dnsRecords;
    };
  };
}
