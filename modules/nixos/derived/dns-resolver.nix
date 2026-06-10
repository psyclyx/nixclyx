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

  v4s = lib.filter (a: a != null)
    (lib.mapAttrsToList (_: a: a.ipv4 or null) addrMap);
  v6s = lib.filter (a: a != null)
    (lib.mapAttrsToList (_: a: a.ipv6 or null) addrMap);
in {
  config = lib.mkIf config.psyclyx.nixos.network.dns.resolver.enable {
    psyclyx.nixos.network.dns.resolver.interfaces = v4s ++ v6s ++ [ "::" ];
  };
}
