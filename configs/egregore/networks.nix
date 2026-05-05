# Network segments — IP-routable scopes.
#
# Apartment networks are VLAN-backed and live at the apt site.
# vpn is the WG overlay: not VLAN-backed, no site (it spans sites).
{
  gate = "always";
  config = {
    entities = {
      main  = { type = "network"; network = { site = "apt"; vlan = 10;  ipv4 = "10.0.10.0/24";  ulaSubnetHex = "a";  ipv6PdSubnetId = 0; }; };
      infra = { type = "network"; network = { site = "apt"; vlan = 25;  ipv4 = "10.0.25.0/24";  ulaSubnetHex = "19"; ipv6PdSubnetId = 1; }; };
      prod  = { type = "network"; network = { site = "apt"; vlan = 30;  ipv4 = "10.0.30.0/24";  ulaSubnetHex = "1e"; ipv6PdSubnetId = 2; }; };
      stage = { type = "network"; network = { site = "apt"; vlan = 31;  ipv4 = "10.0.31.0/24";  ulaSubnetHex = "1f"; ipv6PdSubnetId = 3; }; };
      data  = { type = "network"; network = { site = "apt"; vlan = 50;  ipv4 = "10.0.50.0/24";  ulaSubnetHex = "32"; ipv6PdSubnetId = 4; }; };
      guest = { type = "network"; network = { site = "apt"; vlan = 100; ipv4 = "10.0.100.0/24"; ulaSubnetHex = "64"; ipv6PdSubnetId = 5; }; };
      iot   = { type = "network"; network = { site = "apt"; vlan = 110; ipv4 = "10.0.110.0/24"; ulaSubnetHex = "6e"; ipv6PdSubnetId = 6; }; };
      mgmt  = { type = "network"; network = { site = "apt"; vlan = 240; ipv4 = "10.0.240.0/24"; ulaSubnetHex = "f0"; ipv6PdSubnetId = 7; }; };

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
