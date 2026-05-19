# Network segments — IP-routable scopes.
#
# Apartment networks are VLAN-backed and live at the apt site. The `storage`
# and `lab` networks are routed by mdf-agg01 (CRS326) — see refs.gateway
# below; the site-level default of iyr applies to the rest.
#
# vpn is the WG overlay: not VLAN-backed, no site (it spans sites).
{
  gate = "always";
  config = {
    entities = {
      main    = { type = "network"; network = { site = "apt"; vlan = 10;  ipv4 = "10.0.10.0/24";  ulaSubnetHex = "a";  ipv6PdSubnetId = 0; }; };
      infra   = { type = "network"; network = { site = "apt"; vlan = 25;  ipv4 = "10.0.25.0/24";  ulaSubnetHex = "19"; ipv6PdSubnetId = 1; }; };
      # prod/stage/data (VLANs 30/31/50) retired in the 2026 rework. The
      # lab traffic they carried moved to storage(200)/lab(210), both
      # routed by mdf-agg01 below.
      guest   = { type = "network"; network = { site = "apt"; vlan = 100; ipv4 = "10.0.100.0/24"; ulaSubnetHex = "64"; ipv6PdSubnetId = 5; }; };
      iot     = { type = "network"; network = { site = "apt"; vlan = 110; ipv4 = "10.0.110.0/24"; ulaSubnetHex = "6e"; ipv6PdSubnetId = 6; }; };
      # iyr isn't the gateway for storage/lab (mdf-agg01 is) but it
      # *is* an L2 listener on both VLANs (DHCP + DNS). refs.dns
      # points the DHCP projection's domain-name-servers option at
      # iyr's address on each network, not the switch's.
      storage = {
        type = "network";
        refs = { gateway = "mdf-agg01"; dns = "iyr"; };
        network = { site = "apt"; vlan = 200; ipv4 = "10.0.200.0/24"; ulaSubnetHex = "c8"; ipv6PdSubnetId = 8; mtu = 9000; };
      };
      lab     = {
        type = "network";
        refs = { gateway = "mdf-agg01"; dns = "iyr"; };
        network = { site = "apt"; vlan = 210; ipv4 = "10.0.210.0/24"; ulaSubnetHex = "d2"; ipv6PdSubnetId = 9; };
      };
      mgmt    = { type = "network"; network = { site = "apt"; vlan = 240; ipv4 = "10.0.240.0/24"; ulaSubnetHex = "f0"; ipv6PdSubnetId = 7; }; };

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
        };
      };
    };
  };
}
