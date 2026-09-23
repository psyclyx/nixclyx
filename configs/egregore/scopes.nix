# Reachability scopes for the psyclyx fleet.
#
# Each scope names a reachability scope: the host address key it maps
# to, plus a ref to the DNS view whose record set answers its names.
# Who terminates ingress for a scope is a service — `service.proxy` on
# proxy-tleilax (public, vpn) and proxy-iyr (apt) — not a property of
# the scope, so it is not declared here.
#
#   public — publicly-resolvable services, served on tleilax's public IP.
#   vpn    — *.psyclyx.net over the WG overlay.
#   apt    — *.psyclyx.net on the apartment LAN.
#
# The DNS view ref (`view`) says which record set the scope's names are
# answered from (see dns-views.nix): the public scope from the
# authoritative zones, the internal scopes from resolver-localzone
# records — split-horizon: one name, two views. Certs follow the domain,
# not the scope.
#
# Multi-scope services (e.g. light) override per-scope ingress when
# the default ingressor isn't who they want.
{
  gate = "always";
  config = {
    scopes = {
      public = { address = "public"; view = "public"; };
      vpn    = { address = "vpn";    view = "internal"; };
      apt    = { address = "main";   view = "internal"; };
    };
  };
}
