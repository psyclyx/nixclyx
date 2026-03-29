# VLAN-backed networks. The "vpn" pseudo-network (WireGuard overlay) is
# defined in wireguard.nix, not here — but hosts reference it in
# addresses.vpn and exporter network lists.
{
  main = {
    vlan = 10;
    ipv4 = "10.0.10.0/24";
    ulaSubnetHex = "a";
    ipv6PdSubnetId = 0;
  };
  infra = {
    vlan = 25;
    ipv4 = "10.0.25.0/24";
    ulaSubnetHex = "19";
    ipv6PdSubnetId = 1;
  };
  prod = {
    vlan = 30;
    ipv4 = "10.0.30.0/24";
    ulaSubnetHex = "1e";
    ipv6PdSubnetId = 2;
  };
  stage = {
    vlan = 31;
    ipv4 = "10.0.31.0/24";
    ulaSubnetHex = "1f";
    ipv6PdSubnetId = 3;
  };
  data = {
    vlan = 50;
    ipv4 = "10.0.50.0/24";
    ulaSubnetHex = "32";
    ipv6PdSubnetId = 4;
  };
  guest = {
    vlan = 100;
    ipv4 = "10.0.100.0/24";
    ulaSubnetHex = "64";
    ipv6PdSubnetId = 5;
  };
  iot = {
    vlan = 110;
    ipv4 = "10.0.110.0/24";
    ulaSubnetHex = "6e";
    ipv6PdSubnetId = 6;
  };
  mgmt = {
    vlan = 240;
    ipv4 = "10.0.240.0/24";
    ulaSubnetHex = "f0";
    ipv6PdSubnetId = 7;
  };
}
