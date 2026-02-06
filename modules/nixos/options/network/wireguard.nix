{
  path = ["psyclyx" "nixos" "network" "wireguard"];
  description = "WireGuard VPN (hub-and-spoke)";
  config = {config, lib, nixclyx, ...}: let
    wg = nixclyx.wireguard;
    self = config.psyclyx.nixos.host;
    selfPeer = wg.peers.${self};
    hub = wg.peers.${wg.hub};
    isHub = self == wg.hub;
    spokes = lib.filterAttrs (n: _: n != wg.hub) wg.peers;
  in {
    systemd.network = {
      netdevs."30-${wg.interface}" = {
        netdevConfig = {
          Name = wg.interface;
          Kind = "wireguard";
        };
        wireguardConfig = {
          PrivateKeyFile = "/etc/secrets/wireguard/private.key";
        } // lib.optionalAttrs isHub {
          ListenPort = wg.port;
        };
        wireguardPeers =
          if isHub
          then
            lib.mapAttrsToList (_: peer: {
              PublicKey = peer.publicKey;
              AllowedIPs = ["${peer.ip4}/32" "${peer.ip6}/128"];
            }) spokes
          else [
            {
              PublicKey = hub.publicKey;
              AllowedIPs = wg.allSubnets4 ++ wg.allSubnets6;
              Endpoint = "${hub.endpoint}:${toString wg.port}";
              PersistentKeepalive = 25;
            }
          ];
      };

      networks."30-${wg.interface}" = {
        matchConfig.Name = wg.interface;
        address = [
          "${selfPeer.ip4}/24"
          "${selfPeer.ip6}/64"
        ];
        dns = [hub.ip4 hub.ip6];
        domains = ["~psyclyx.net" "~psyclyx.xyz"];
      };
    };

    boot.kernel.sysctl = lib.mkIf isHub {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    networking.firewall = {
      trustedInterfaces = [wg.interface];
    } // lib.optionalAttrs isHub {
      allowedUDPPorts = [wg.port];
    };

    systemd.network.wait-online.ignoredInterfaces = [wg.interface];
  };
}
