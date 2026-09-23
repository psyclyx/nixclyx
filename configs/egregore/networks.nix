# Network segments — IP-routable scopes.
#
# Apartment networks are VLAN-backed and live at the apt site. `storage`
# and `lab` are routed by mdf-agg01 (CRS326) — see refs.gateway below;
# the site-level default of iyr applies to the rest.
#
# vpn is the WG overlay: not VLAN-backed, no site (it spans sites).
#
# Each network declares a `zone` for policy lookup. Zones are defined in
# zones.nix; forward policy in globals.nix is keyed by (src-zone, dst-zone).
{
  gate = "always";
  config = {
    entities = {
      # main relays DHCP even though iyr is L2-present here: broadcast
      # DISCOVERs from the lab hosts' eno1 reach mdf-agg01 (their MACs
      # learn on vlan10) but die somewhere on the CSS326 → CRS326 →
      # mdf-brk01 flood path and never arrive at Kea. Relaying from the
      # SVI that already sees the frame routes around the broken flood.
      # mdf-agg01 routes v4 here; iyr keeps v6. The cutover is v4-only —
      # v6 default-router selection happens through RAs from iyr's
      # link-local, which is untouched by which box holds 10.0.10.1, and
      # iyr is the resolver and the source of the delegated prefix. The
      # switch has no v6 default route to offer, so handing it v6 would
      # black-hole off-net v6 for everything on this VLAN.
      main = {
        
        refs = { gateway = "mdf-agg01"; gateway6 = "iyr"; };
        network = { site = "apt"; vlan = 10; ipv4 = "10.0.10.0/24"; ulaSubnetHex = "a"; ipv6PdSubnetId = 0; dhcpRelay = true; zone = "lan"; };
      };
      # Routed by mdf-agg01 like every other internal segment. iyr was
      # its gateway only because it predates the switch having usable L3
      # offload — infra has no property that wants a stateful router in
      # front of it, and putting it on the switch means east-west between
      # infra hosts is hardware-routed rather than hairpinned.
      #
      # v6 stays with iyr for the same reason as main: the switch has no
      # ::/0 to offer yet.
      infra = {
        
        refs = { gateway = "mdf-agg01"; gateway6 = "iyr"; };
        network = { site = "apt"; vlan = 25; ipv4 = "10.0.25.0/24"; ulaSubnetHex = "19"; ipv6PdSubnetId = 1; zone = "infra"; };
      };
      # iyr isn't the gateway for storage/lab (mdf-agg01 is) but it *is*
      # an L2 listener on both (DHCP + DNS).
      # refs.dns points the DHCP projection's domain-name-servers option
      # at iyr's address on each network, not the switch's.
      # storage/lab relay *and* keep iyr's L2 anchor for now. The relay is
      # additive, so running both proves the relayed path carries real
      # traffic before the enp1s0.200 / enp1s0.210 anchors come out — at
      # which point iyr needs only one address here and the L2-anchor
      # requirement in CLAUDE.md goes away.
      storage = {
        
        refs = { gateway = "mdf-agg01"; dns = "iyr"; };
        network = { site = "apt"; vlan = 200; ipv4 = "10.0.200.0/24"; ulaSubnetHex = "c8"; ipv6PdSubnetId = 8; mtu = 9000; dhcpRelay = true; zone = "storage"; };
      };
      # lab/210 — currently still an L2 VLAN serving lab hosts; under
      # the v3 rework the 10.0.210.0/24 supernet becomes the routed
      # lab-transit /30 family and VLAN tag 210 is retired. Keeping
      # vlan = 210 for now so existing lab-host addresses continue to
      # work through phases 1-3; phase 4 (hypervisor BGP) flips this
      # to vlan = null.
      lab = {
        
        refs = { gateway = "mdf-agg01"; dns = "iyr"; };
        network = { site = "apt"; vlan = 210; ipv4 = "10.0.210.0/24"; ulaSubnetHex = "d2"; ipv6PdSubnetId = 9; dhcpRelay = true; zone = "lab-transit"; };
      };

      mgmt = {
        
        network = { site = "apt"; vlan = 240; ipv4 = "10.0.240.0/24"; ulaSubnetHex = "f0"; ipv6PdSubnetId = 7; zone = "mgmt"; };
      };

      # LAN core transit — the point-to-point iyr↔mdf-agg01 link for the
      # router-on-a-stick migration: mdf-agg01 L3-routes inter-VLAN in
      # hardware and hands north-south to iyr (NAT) over this /30. No DHCP,
      # no clients — iyr .1, mdf-agg01 .2.
      core-transit = {
        
        tags = ["transit"];
        network = { site = "apt"; vlan = 252; ipv4 = "10.0.252.0/30"; ulaSubnetHex = "fc"; zone = "core-transit"; };
      };

      vpn = {
        
        tags = ["overlay" "wireguard"];
        refs = {
          dns = "tleilax";
          gateway = "tleilax";
        };
        network = {
          # No vlan, no site — overlay spans sites via WG.
          ipv4 = "10.157.0.0/24";
          # Within apt, reach VPN peers via the main LAN instead of
          # hairpinning through the WG hub. Apt-resident peers (e.g.
          # lab-1..4) own their VPN IP on wg0 but accept it on any
          # interface; the apt site router emits /32 routes from this.
          underlay.apt = "main";
          zone = "wg";
        };
      };
    };
  };
}
