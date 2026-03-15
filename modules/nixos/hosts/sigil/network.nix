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

      # Direct peer to iyr over LAN (bypasses tleilax VPN hub)
      netdevs."30-wg0".wireguardPeers = lib.mkAfter [
        {
          PublicKey = "9wnevbvkDGcyNnMECEzgfaghqi4tEw4GsgC/TUcSTS4=";
          Endpoint = "10.0.10.1:51820";
          AllowedIPs = [
            "10.157.0.2/32"
            "10.0.10.0/24"
            "10.0.25.0/24"
            "10.0.30.0/24"
            "10.0.31.0/24"
            "10.0.50.0/24"
            "10.0.100.0/24"
            "10.0.110.0/24"
            "10.0.240.0/24"
          ];
          PersistentKeepalive = 25;
        }
      ];

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
      };
    };
  };
}
