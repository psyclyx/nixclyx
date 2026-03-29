{config, lib, ...}: let
  eg = config.psyclyx.egregore;

  wgHosts = lib.filterAttrs (_: e:
    e.type == "host" && e.host.wireguard != null
  ) eg.entities;

  dnsRecords = lib.concatLists (lib.mapAttrsToList (name: e: [
    "${name}.${eg.domains.internal}. IN A ${e.host.addresses.vpn.ipv4}"
  ]) wgHosts);
in {
  config = lib.mkIf config.psyclyx.nixos.network.dns.resolver.enable {
    psyclyx.nixos.network.dns.resolver.localZones.${eg.domains.internal} = {
      type = lib.mkDefault "transparent";
      records = dnsRecords;
    };
  };
}
