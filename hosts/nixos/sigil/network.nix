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
      # No static dns / domains: iyr's DHCP advertises itself as the
      # only DNS server, and DHCP-provided search domains are
      # search-only (UseDomains=true). With no routing-only `~xxx`
      # domains on the link, systemd-resolved's auto mode treats br0
      # as the default DNS link, so every query — internal or public
      # — goes through iyr's Unbound.
    };
  };
}
