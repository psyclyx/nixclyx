# VPN overlay DNS zone (vpn.psyclyx.net).
#
# Generates an authoritative zone on the overlay hub with A records
# for all WireGuard-enabled hosts, keyed by VPN IP.
{config, lib, ...}: let
  eg = config.psyclyx.egregore;
  hostName = config.networking.hostName;
  isHub = hostName == eg.overlay.hub;

  wgHosts = lib.filterAttrs (_: e:
    e.type == "host" && e.host.wireguard != null
  ) eg.entities;

  vpnZoneName = "vpn.${eg.domains.internal}";

  hubVpnIp = eg.entities.${eg.overlay.hub}.host.addresses.vpn.ipv4;

  hostRecords = lib.concatMapStringsSep "\n" (name: let
    addr = eg.entities.${name}.host.addresses.vpn.ipv4;
  in "${name} IN A ${addr}")
  (lib.sort builtins.lessThan (builtins.attrNames wgHosts));
in {
  config = lib.mkIf isHub {
    psyclyx.nixos.network.dns.authoritative.zones.${vpnZoneName} = {
      ddns = false;
      data = ''
        $ORIGIN ${vpnZoneName}.
        $TTL 300
        @    IN SOA  ns1.${vpnZoneName}. admin.${vpnZoneName}. (
                     1 3600 900 604800 300 )
        @    IN NS   ns1.${vpnZoneName}.
        ns1  IN A    ${hubVpnIp}
        ${hostRecords}
      '';
    };
  };
}
