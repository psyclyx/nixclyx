{
  main = {
    vlan = 10;
    ipv4 = "10.0.10.0/24";
    ipv6Suffix = "a";
    ipv6PdSubnetId = 0;
  };
  rack = {
    vlan = 20;
    ipv4 = "10.157.10.0/24";
    ipv6Suffix = "14";
    ipv6PdSubnetId = 1;
  };
  data = {
    vlan = 30;
    ipv4 = "10.0.30.0/24";
    ipv6Suffix = "1e";
    ipv6PdSubnetId = 2;
  };
  mgmt = {
    vlan = 240;
    ipv4 = "10.0.240.0/24";
    ipv6Suffix = "f0";
    ipv6PdSubnetId = 5;
  };
}
