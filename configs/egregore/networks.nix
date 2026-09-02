# Network segments — IP-routable scopes.
#
# Apartment networks are VLAN-backed and live at the apt site. The `storage`,
# `lab`, and cluster-* networks are routed by mdf-agg01 (CRS326) — see
# refs.gateway below; the site-level default of iyr applies to the rest.
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
      main = {
        type = "network";
        network = { site = "apt"; vlan = 10; ipv4 = "10.0.10.0/24"; ulaSubnetHex = "a"; ipv6PdSubnetId = 0; dhcpRelay = true; zone = "lan"; };
      };
      infra = {
        type = "network";
        network = { site = "apt"; vlan = 25; ipv4 = "10.0.25.0/24"; ulaSubnetHex = "19"; ipv6PdSubnetId = 1; zone = "infra"; };
      };
      # iyr isn't the gateway for storage/lab/cluster-* (mdf-agg01 is)
      # but it *is* an L2 listener on storage + lab (DHCP + DNS).
      # refs.dns points the DHCP projection's domain-name-servers option
      # at iyr's address on each network, not the switch's.
      # storage/lab relay *and* keep iyr's L2 anchor for now. The relay is
      # additive, so running both proves the relayed path carries real
      # traffic before the enp1s0.200 / enp1s0.210 anchors come out — at
      # which point iyr needs only one address here and the L2-anchor
      # requirement in CLAUDE.md goes away.
      storage = {
        type = "network";
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
        type = "network";
        refs = { gateway = "mdf-agg01"; dns = "iyr"; };
        network = { site = "apt"; vlan = 210; ipv4 = "10.0.210.0/24"; ulaSubnetHex = "d2"; ipv6PdSubnetId = 9; dhcpRelay = true; zone = "lab-transit"; };
      };

      # Cluster env networks (VLANs 220-223). Routed at mdf-agg01; DHCP
      # relayed to iyr (Kea) via mdf-agg01 — iyr has no L2 presence on
      # these VLANs at all, so the relay isn't an optimisation here, it's
      # the only path a DISCOVER has. Each lab host hosts
      # a bridge for each env on a dedicated 1G access port — see
      # docs/lab-v3.md.
      # Cluster env PD subnet IDs fit in the Xfinity /60 (4 bits → 0..15);
      # 12-15 are the trailing slice, keeping 0-11 for apt-side use.
      cluster-prod = {
        type = "network";
        refs = { gateway = "mdf-agg01"; dns = "iyr"; };
        network = { site = "apt"; vlan = 220; ipv4 = "10.0.220.0/24"; ulaSubnetHex = "dc"; ipv6PdSubnetId = 12; dhcpRelay = true; zone = "cluster-workload"; };
      };
      cluster-stage = {
        type = "network";
        refs = { gateway = "mdf-agg01"; dns = "iyr"; };
        network = { site = "apt"; vlan = 221; ipv4 = "10.0.221.0/24"; ulaSubnetHex = "dd"; ipv6PdSubnetId = 13; dhcpRelay = true; zone = "cluster-workload"; };
      };
      cluster-scratch = {
        type = "network";
        refs = { gateway = "mdf-agg01"; dns = "iyr"; };
        network = { site = "apt"; vlan = 222; ipv4 = "10.0.222.0/24"; ulaSubnetHex = "de"; ipv6PdSubnetId = 14; dhcpRelay = true; zone = "cluster-scratch"; };
      };
      cluster-orch = {
        type = "network";
        refs = { gateway = "mdf-agg01"; dns = "iyr"; };
        network = { site = "apt"; vlan = 223; ipv4 = "10.0.223.0/24"; ulaSubnetHex = "df"; ipv6PdSubnetId = 15; dhcpRelay = true; zone = "cluster-orch"; };
      };

      mgmt = {
        type = "network";
        network = { site = "apt"; vlan = 240; ipv4 = "10.0.240.0/24"; ulaSubnetHex = "f0"; ipv6PdSubnetId = 7; zone = "mgmt"; };
      };

      # LAN core transit — the point-to-point iyr↔mdf-agg01 link for the
      # router-on-a-stick migration: mdf-agg01 L3-routes inter-VLAN in
      # hardware and hands north-south to iyr (NAT) over this /30. No DHCP,
      # no clients — iyr .1, mdf-agg01 .2.
      core-transit = {
        type = "network";
        tags = ["transit"];
        network = { site = "apt"; vlan = 252; ipv4 = "10.0.252.0/30"; ulaSubnetHex = "fc"; zone = "core-transit"; };
      };

      vpn = {
        type = "network";
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
