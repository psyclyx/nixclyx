{
  config,
  lib,
  ...
}: {
  config = lib.mkIf (config.psyclyx.nixos.host == "sigil") {
    systemd.network.networks."20-sfp" = {
      matchConfig.Name = "enp5s0f?";
      networkConfig = {
        Domains = ["~."];
        DHCP = "yes";
      };
      dhcpV4Config = {
        UseDNS = true;
        UseRoutes = true;
        RouteMetric = 100;
      };
      dhcpV6Config = {
        UseDNS = true;
      };
    };
  };
}
