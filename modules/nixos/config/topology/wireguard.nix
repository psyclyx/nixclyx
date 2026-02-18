{
  config,
  lib,
  ...
}: let
  topo = config.psyclyx.topology;
  hostName = config.networking.hostName;
  thisHost = topo.hosts.${hostName} or null;
  hasVpn = thisHost != null && thisHost.vpn != null;

  hubHost = topo.hosts.${topo.vpn.hub};
  isHub = hasVpn && hostName == topo.vpn.hub;

  vpnPeers = lib.filterAttrs (name: host:
    name != hostName && host.vpn != null
  ) topo.hosts;

  allPeerExportedRoutes = lib.concatMap
    (host: host.vpn.exportedRoutes or [])
    (lib.attrValues vpnPeers);
in {
  config = lib.mkIf hasVpn {
    networking.firewall.allowedUDPPorts = [topo.vpn.port];

    systemd.network = {
      netdevs."30-wg0" = {
        netdevConfig = {
          Kind = "wireguard";
          Name = "wg0";
        };

        wireguardConfig = lib.mkMerge [
          {PrivateKeyFile = "/etc/secrets/wireguard/private.key";}
          (lib.mkIf isHub {ListenPort = topo.vpn.port;})
        ];

        wireguardPeers =
          if isHub
          then
            # Hub: one peer entry per VPN host
            lib.mapAttrsToList (_: host: {
              PublicKey = host.vpn.publicKey;
              AllowedIPs = ["${host.vpn.address}/32"] ++ host.vpn.exportedRoutes;
            })
            vpnPeers
          else
            # Spoke: single peer entry for the hub
            [
              {
                PublicKey = hubHost.vpn.publicKey;
                Endpoint = "vpn.${topo.domain.public}:${toString topo.vpn.port}";
                AllowedIPs = [topo.vpn.subnet] ++ allPeerExportedRoutes;
                PersistentKeepalive = 25;
              }
            ];
      };

      networks."30-wg0" = lib.mkMerge [
        {
          matchConfig.Name = "wg0";
          address = ["${thisHost.vpn.address}/24"];
        }
        # Spoke peers: route internal domain queries through VPN DNS
        (lib.mkIf (!isHub) {
          dns = [hubHost.vpn.address];
          domains = ["~${topo.domain.internal}"];
        })
      ];
    };
  };
}
