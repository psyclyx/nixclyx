{...}: {
  psyclyx.nixos.network.interfaces = {
    bonds.bond0 = {
      slaves = "enp5s0f?";
      mode = "802.3ad";
      lacpTransmitRate = "fast";
      hashPolicy = "layer3+4";
      miiMonitorSec = "1s";
    };
    bridges.br0.member = "bond0";
    networks.br0 = {
      dhcp = true;
      dns = ["10.0.10.1"];
      domains = [
        "~apt.psyclyx.net"
        "infra.apt.psyclyx.net"
        "apt.psyclyx.net"
        "mgmt.apt.psyclyx.net"
      ];
    };
  };
}
