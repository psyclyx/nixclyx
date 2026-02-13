{
  config,
  lib,
  ...
}:
lib.mkIf (config.psyclyx.host == "tleilax") {
  config = {
    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
    boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

    networking.firewall = {
      allowedUDPPorts = [51820];
      trustedInterfaces = ["wg0"];
    };

    systemd.network = {
      netdevs = {
        "30-wg0" = {
          netdevConfig = {
            Kind = "wireguard";
            Name = "wg0";
          };
          wireguardConfig = {
            ListenPort = 51820;
            PrivateKeyFile = "/etc/wireguard/private.key";
          };
          wireguardPeers = [
            {
              # iyr
              PublicKey = "9wnevbvkDGcyNnMECEzgfaghqi4tEw4GsgC/TUcSTS4=";
              AllowedIPs = [
                "10.0.10.0/24"
                "10.157.0.2/32"
              ];
            }
            {
              # sigil
              PublicKey = "XKqqjC62uOUhbCn3JPpI0M6WFYqRf8sLpML90JZ1CmE=";
              AllowedIPs = ["10.157.0.3/32"];
            }
          ];
        };
      };

      networks = {
        "30-wg0" = {
          matchConfig.Name = "wg0";
          address = ["10.157.0.1/24"];
          networkConfig = {
            IPForward = "yes";
          };
        };
      };
    };
  };
}
