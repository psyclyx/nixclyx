# Project a host's effective DNS authority into authoritative.zones.
#
# Each zone (intrinsic + any apex contributed by services via
# refs.dnsAuthority) becomes an entry in
# psyclyx.nixos.network.dns.authoritative.zones with default TTL and
# DDNS enabled. Per-zone overrides (extraRecords, custom data, etc.)
# still merge by zone key, so callers can keep declaring fragments
# without duplicating the bare zone enablement.
{ config, lib, ... }:
let
  eg = config.psyclyx.egregore;
  hostName = config.psyclyx.nixos.host;
  me = eg.entities.${hostName} or null;
  intrinsic = if me != null && me.type == "host" then me.host.dnsAuthority or [] else [];
  sources = if me != null then me.attrs.refsIn.dnsAuthority or [] else [];
  contributed = lib.concatMap (n: let
    e = eg.entities.${n} or null;
  in lib.optional (e != null && e.type == "service" && e.attrs.resolvedDomain != null)
    e.attrs.resolvedDomain) sources;
  zones = lib.unique (intrinsic ++ contributed);
in
{
  config = lib.mkIf (zones != [ ]) {
    psyclyx.nixos.network.dns.authoritative.zones = lib.genAttrs zones (_: {
      ttl = 3600;
      ddns = true;
    });
  };
}
