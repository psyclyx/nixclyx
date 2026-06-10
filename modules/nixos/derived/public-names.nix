# Egregore → public-zone A/AAAA records.
#
# For each host with `publicNames` declared, emits
# `<name> IN A <ipv4>` (and AAAA if available) records pointing at
# that host's public address. Records are appended to the
# `globals.domains.public` zone on whichever host owns that zone via
# its `dnsAuthority` list.
#
# Activates only on the zone-owning host — no-op everywhere else.
{config, lib, ...}: let
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;
  me = eg.entities.${hostname} or null;

  publicDomain = eg.domains.public or "";

  ownsPublicZone =
    publicDomain != ""
    && me != null
    && builtins.elem publicDomain (me.host.dnsAuthority or []);

  hostsWithPublicNames = lib.filterAttrs
    (_: e: e.type == "host" && (e.host.publicNames or []) != [])
    eg.entities;

  mkRecords = _hostName: hostEnt: let
    pub = hostEnt.host.addresses.public or {};
    v4 = pub.ipv4 or null;
    v6 = pub.ipv6 or null;
    mkOne = name:
      (lib.optionalString (v4 != null) "${name}    IN A     ${v4}\n")
      + (lib.optionalString (v6 != null) "${name}    IN AAAA  ${v6}\n");
  in
    if v4 == null && v6 == null then ""
    else lib.concatStrings (map mkOne hostEnt.host.publicNames);

  fragment = lib.concatStrings
    (lib.mapAttrsToList mkRecords hostsWithPublicNames);
in {
  config = lib.mkIf (ownsPublicZone && fragment != "") {
    psyclyx.nixos.network.dns.authoritative.zones.${publicDomain}.extraRecords = fragment;
  };
}
