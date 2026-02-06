{
  path = ["psyclyx" "nixos" "network" "wireguard"];
  description = "WireGuard VPN (multi-site hub topology)";
  config = {config, lib, nixclyx, ...}: let
    wg = nixclyx.wireguard;
    self = config.psyclyx.nixos.host;
    selfPeer = wg.peers.${self};
    selfSite = wg.sites.${selfPeer.site};

    rootHubName = wg.rootHub;
    rootHub = wg.peers.${rootHubName};
    rootSite = wg.sites.${rootHub.site};

    # Is this peer a hub?
    isRootHub = self == rootHubName;
    isSiteHub = selfSite.hub or null == self;
    isHub = isRootHub || isSiteHub;

    # Get the hub this peer should connect to
    getHubFor = peer: let
      peerSite = wg.sites.${peer.site};
      siteHub = peerSite.hub or null;
    in
      if siteHub != null then siteHub
      else rootHubName;

    myHub = getHubFor selfPeer;
    myHubPeer = wg.peers.${myHub};

    # For root hub: all peers except self
    # For site hub: local peers + root hub
    # For regular peer: just my hub
    wireguardPeers =
      if isRootHub then
        # Root hub peers with everyone
        lib.mapAttrsToList (name: peer: {
          PublicKey = peer.publicKey;
          AllowedIPs = ["${peer.ip4}/32" "${peer.ip6}/128"];
        }) (lib.filterAttrs (n: _: n != self) wg.peers)

      else if isSiteHub then
        # Site hub peers with:
        # 1. Root hub (routes all non-local subnets)
        # 2. Local site peers
        let
          localPeers = lib.filterAttrs (n: p:
            n != self && p.site == selfPeer.site
          ) wg.peers;

          otherSubnets = lib.filter (s:
            s != selfSite.subnet4 && s != selfSite.subnet6
          ) (wg.allSubnets4 ++ wg.allSubnets6);
        in
          # Root hub peer
          [{
            PublicKey = rootHub.publicKey;
            AllowedIPs = otherSubnets;
            Endpoint = "${rootHub.endpoint}:${toString wg.port}";
            PersistentKeepalive = 25;
          }]
          # Local peers
          ++ lib.mapAttrsToList (name: peer: {
            PublicKey = peer.publicKey;
            AllowedIPs = ["${peer.ip4}/32" "${peer.ip6}/128"];
          }) localPeers

      else
        # Regular peer: connect to hub
        [{
          PublicKey = myHubPeer.publicKey;
          AllowedIPs = wg.allSubnets4 ++ wg.allSubnets6;
          Endpoint = "${myHubPeer.endpoint}:${toString wg.port}";
          PersistentKeepalive = 25;
        }];

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
        inherit wireguardPeers;
      };

      networks."30-${wg.interface}" = {
        matchConfig.Name = wg.interface;
        address = [
          "${selfPeer.ip4}/24"
          "${selfPeer.ip6}/64"
        ];
        dns = [rootHub.ip4 rootHub.ip6];
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
