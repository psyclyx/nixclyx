# Egregore → DNS resolver listen addresses.
#
# When this host runs the DNS resolver, listen on every IPv4 and IPv6
# this host has on any fleet network (declared addresses + gateway-
# derived addresses for networks the host gateways), plus IPv6 ANY
# for fe80 link-locals and unconfigured-time queries.
#
# Hosts may still append host-intrinsic addresses (e.g. untagged trunk
# IPs that aren't modeled in egregore) — list-merging combines them.
{config, lib, ...}: let
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;
  meAttrs = lib.attrByPath ["entities" hostname "attrs"] {} eg;
  addrMap = meAttrs.addresses or {};

  # Exclude any address the authoritative DNS already binds on this
  # host — knot and unbound can't both listen on the same address:53.
  authoritativeBound =
    config.psyclyx.nixos.network.dns.authoritative.interfaces or [];
  isBound = a: builtins.elem a authoritativeBound;

  v4s = lib.filter (a: a != null && !(isBound a))
    (lib.mapAttrsToList (_: a: a.ipv4 or null) addrMap);
  v6s = lib.filter (a: a != null && !(isBound a))
    (lib.mapAttrsToList (_: a: a.ipv6 or null) addrMap);

  # Wildcard IPv6 (::) was historically added so fe80 link-locals
  # work pre-config. Skip it when authoritative DNS binds any IPv6
  # — both can't claim port 53.
  authoritativeHasV6 = builtins.any (a: lib.hasInfix ":" a) authoritativeBound;
in {
  config = lib.mkIf config.psyclyx.nixos.network.dns.resolver.enable {
    psyclyx.nixos.network.dns.resolver.interfaces =
      v4s ++ v6s ++ lib.optional (!authoritativeHasV6) "::";
  };
}
