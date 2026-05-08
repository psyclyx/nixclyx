# Project host.dnsAuthority into authoritative.zones.
#
# Each zone in this host's dnsAuthority list becomes an entry in
# psyclyx.nixos.network.dns.authoritative.zones with default TTL and
# DDNS enabled. Per-zone overrides (extraRecords, custom data, etc.)
# still merge by zone key, so callers can keep declaring fragments
# without duplicating the bare zone enablement.
{ config, lib, ... }:
let
  eg = config.psyclyx.egregore;
  hostName = config.psyclyx.nixos.host;
  me = eg.entities.${hostName} or null;
  zones = if me != null && me.type == "host" then me.host.dnsAuthority or [ ] else [ ];
in
{
  config = lib.mkIf (zones != [ ]) {
    psyclyx.nixos.network.dns.authoritative.zones = lib.genAttrs zones (_: {
      ttl = 3600;
      ddns = true;
    });
  };
}
