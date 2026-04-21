# Cross-site DNS forwarding derived from egregore topology.
#
# Each site DNS server auto-forwards other sites' domains to the
# remote site's DNS server via VPN. Also forwards vpn.psyclyx.net
# to the overlay hub for non-hub resolvers.
{config, lib, ...}: let
  eg = config.psyclyx.egregore;
  hostName = config.networking.hostName;

  # All sites with a dns ref and a domain.
  dnsSites = lib.filterAttrs (_: e:
    e.type == "site" && e.site.domain != null && e.refs ? dns
  ) eg.entities;

  # My site (if any).
  me = eg.entities.${hostName} or null;
  mySiteName = if me != null && me.type == "host" then me.host.site or null else null;

  # Am I a site DNS server?
  isSiteDns = builtins.any (site:
    site.refs.dns == hostName
  ) (builtins.attrValues dnsSites);

  # Forward zones for other sites' domains.
  otherSiteForwards = lib.mapAttrs' (_siteName: siteEntity: let
    dnsHostName = siteEntity.refs.dns;
    dnsHostVpnIp = eg.entities.${dnsHostName}.host.addresses.vpn.ipv4;
  in lib.nameValuePair siteEntity.site.domain {
    forward-addr = [dnsHostVpnIp];
  }) (lib.filterAttrs (_: site: site.refs.dns != hostName) dnsSites);

  # Forward overlay zones to the hub (unless we are the hub).
  # - vpn.psyclyx.net: VPN peer records
  # - psyclyx.net: service records served by the ingress hub
  isHub = hostName == eg.overlay.hub;
  hubVpnIp = eg.entities.${eg.overlay.hub}.host.addresses.vpn.ipv4;
  hubForwards = lib.optionalAttrs (!isHub) {
    "vpn.${eg.domains.internal}" = { forward-addr = [hubVpnIp]; };
    ${eg.domains.internal} = { forward-addr = [hubVpnIp]; };
  };
in {
  config = lib.mkIf (isSiteDns && config.psyclyx.nixos.network.dns.resolver.enable) {
    psyclyx.nixos.network.dns.resolver.forwardZones =
      otherSiteForwards // hubForwards;
  };
}
