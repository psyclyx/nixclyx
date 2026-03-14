{
  main = {
    vlan = 10;
    ipv4 = "10.0.10.0/24";
    ipv6Suffix = "a";
    ipv6PdSubnetId = 0;
  };
  infra = {
    vlan = 25;
    ipv4 = "10.0.25.0/24";
    ipv6Suffix = "19";
    ipv6PdSubnetId = 1;
  };
  prod = {
    vlan = 30;
    ipv4 = "10.0.30.0/24";
    ipv6Suffix = "1e";
    ipv6PdSubnetId = 2;
  };
  stage = {
    vlan = 31;
    ipv4 = "10.0.31.0/24";
    ipv6Suffix = "1f";
    ipv6PdSubnetId = 3;
  };
  data = {
    vlan = 50;
    ipv4 = "10.0.50.0/24";
    ipv6Suffix = "32";
    ipv6PdSubnetId = 4;
  };
  guest = {
    vlan = 100;
    ipv4 = "10.0.100.0/24";
    ipv6Suffix = "64";
    ipv6PdSubnetId = 5;
  };
  iot = {
    vlan = 110;
    ipv4 = "10.0.110.0/24";
    ipv6Suffix = "6e";
    ipv6PdSubnetId = 6;
  };
  mgmt = {
    vlan = 240;
    ipv4 = "10.0.240.0/24";
    ipv6Suffix = "f0";
    ipv6PdSubnetId = 7;
  };
}
