{
  config,
  lib,
  ...
}: {
  config = lib.mkIf (config.psyclyx.nixos.host == "sigil") {
    networking.firewall.allowedUDPPorts = [51820];
    systemd.network = {
      netdevs = {
        "30-wg0" = {
          netdevConfig = {
            Kind = "wireguard";
            Name = "wg0";
          };

          wireguardConfig = {
            PrivateKeyFile = "/etc/secrets/wireguard/private.key";
          };

          wireguardPeers = [
            {
              # tleilax
              PublicKey = "Hsytr+mjAfsBPoC99XHKLh9+jEbyz1REF0okmlviUVc=";
              Endpoint = "vpn.psyclyx.xyz:51820";
              AllowedIPs = [
                "10.157.0.0/24"
              ];
              PersistentKeepalive = 25;
            }
          ];
        };
      };

      networks = {
        "30-wg0" = {
          matchConfig.Name = "wg0";
          address = ["10.157.0.3/24"];
          dns = ["10.157.0.1"];
          domains = ["~psyclyx.net" "~psyclyx.xyz"];
        };
      };
    };
  };
}
