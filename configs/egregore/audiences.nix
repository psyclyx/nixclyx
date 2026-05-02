# Reachability audiences for the psyclyx fleet.
#
# Each audience names a reachability context: the host address key its
# ingress binds on, and the host that runs ingress by default.
#
#   public — publicly-resolvable services served by tleilax on its
#            public IP (and SSL-terminated there).
#   vpn    — *.psyclyx.net served on the VPN overlay; clients are road
#            warriors over WG.
#   apt    — *.psyclyx.net served on the apartment LAN; clients on the
#            main VLAN hit iyr directly.
#
# Conventions used by the ingress projection:
#   - audience.address == "public"             → DNS in the authoritative
#                                                 zone matching the service
#                                                 domain; cert is the
#                                                 wildcard or per-domain
#                                                 ACME for that zone.
#   - audience.address is a network entity name → DNS in resolver-localzone
#                                                 served by that network's
#                                                 dns ref; cert is the
#                                                 internal wildcard.
#
# Multi-audience services (e.g. light) override per-audience ingress when
# the audience's defaultIngress isn't who they want.
{
  gate = "always";
  config = {
    audiences = {
      public = { address = "public"; defaultIngress = "tleilax"; };
      vpn    = { address = "vpn";    defaultIngress = "tleilax"; };
      apt    = { address = "main";   defaultIngress = "iyr";     };
    };
  };
}
