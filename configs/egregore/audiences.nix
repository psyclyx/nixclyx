# Reachability audiences for the psyclyx fleet.
#
# Each audience names a reachability scope: the host address key it maps
# to. Who terminates ingress for a scope is a service — `service.proxy`
# on proxy-tleilax (public, vpn) and proxy-iyr (apt) — not a property of
# the scope, so it is not declared here.
#
#   public — publicly-resolvable services, served on tleilax's public IP.
#   vpn    — *.psyclyx.net over the WG overlay.
#   apt    — *.psyclyx.net on the apartment LAN.
#
# Conventions used by the ingress projection:
#   - address = "public"            → DNS in the authoritative zone
#                                     matching the service domain; cert is
#                                     the wildcard or per-domain ACME.
#   - address is a network entity   → DNS in resolver-localzone served by
#                                     that network's dns ref; cert is the
#                                     internal wildcard.
#
# Multi-audience services (e.g. light) override per-audience ingress when
# the default ingressor isn't who they want.
{
  gate = "always";
  config = {
    audiences = {
      public = { address = "public"; };
      vpn    = { address = "vpn";    };
      apt    = { address = "main";   };
    };
  };
}
