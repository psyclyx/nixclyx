{
  config,
  lib,
  ...
}: {
  config = lib.mkIf (config.psyclyx.nixos.host == "sigil") {
    systemd.network = {
      netdevs = {
        "10-bond0" = {
          netdevConfig = {
            Name = "bond0";
            Kind = "bond";
          };
          bondConfig = {
            Mode = "802.3ad";
            LACPTransmitRate = "fast";
            TransmitHashPolicy = "layer3+4";
            MIIMonitorSec = "1s";
          };
        };
      };

      networks = {
        "20-bond0-ports" = {
          matchConfig.Name = "enp5s0f?";
          networkConfig = {
            Bond = "bond0";
          };
        };
        "20-bond0" = {
          matchConfig.Name = "bond0";
          networkConfig = {
            DHCP = "yes";
            IPv6AcceptRA = true;
          };
          dhcpV4Config.UseDomains = true;
          dhcpV6Config.WithoutRA = "solicit";
        };
        # "20-sfp" = {
        #   dhcpV4Config = {
        #     UseDNS = true;
        #     UseRoutes = true;
        #     RouteMetric = 100;
        #   };
        #   dhcpV6Config = {
        #     UseDNS = true;
        #   };
        # };
      };
    };
  };
}
