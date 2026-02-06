{
  path = ["psyclyx" "nixos" "network" "wireguard"];
  description = "WireGuard VPN (multi-site hub topology)";
  config = {config, lib, nixclyx, ...}: let
    net = nixclyx.network;
    self = config.psyclyx.nixos.host;
    selfPeer = net.peers.${self};
    selfSite = net.sites.${selfPeer.site};

    rootHubName = net.rootHub;
    rootHub = net.peers.${rootHubName};
    rootSite = net.sites.${rootHub.site};
    port = net.port;

    # Is this peer a hub?
    isRootHub = self == rootHubName;
    isSiteHub = selfSite.hub or null == self;
    isHub = isRootHub || isSiteHub;

    # Check for missing credentials
    selfHasKey = selfPeer.publicKey or null != null;
    hubHasKey = rootHub.publicKey or null != null;

    # Get the hub this peer should connect to
    getHubFor = peer: let
      peerSite = net.sites.${peer.site};
      siteHub = peerSite.hub or null;
    in
      if siteHub != null then siteHub
      else rootHubName;

    myHub = getHubFor selfPeer;
    myHubPeer = net.peers.${myHub};
    myHubHasKey = myHubPeer.publicKey or null != null;

    # Filter to only peers with valid keys
    peersWithKeys = lib.filterAttrs (n: p: p.publicKey or null != null);

    # For root hub: all peers except self (with keys)
    # For site hub: local peers + root hub (with keys)
    # For regular peer: just my hub (if has key)
    wireguardPeers =
      if isRootHub then
        lib.mapAttrsToList (name: peer: {
          PublicKey = peer.publicKey;
          AllowedIPs = ["${peer.ip4}/32" "${peer.ip6}/128"];
        }) (peersWithKeys (lib.filterAttrs (n: _: n != self) net.peers))

      else if isSiteHub then
        let
          localPeers = peersWithKeys (lib.filterAttrs (n: p:
            n != self && p.site == selfPeer.site
          ) net.peers);

          otherSubnets = lib.filter (s:
            s != selfSite.subnet4 && s != selfSite.subnet6
          ) (net.allSubnets4 ++ net.allSubnets6);
        in
          # Root hub peer (if has key)
          (lib.optional hubHasKey {
            PublicKey = rootHub.publicKey;
            AllowedIPs = otherSubnets;
            Endpoint = "${rootHub.endpoint}:${toString port}";
            PersistentKeepalive = 25;
          })
          # Local peers
          ++ lib.mapAttrsToList (name: peer: {
            PublicKey = peer.publicKey;
            AllowedIPs = ["${peer.ip4}/32" "${peer.ip6}/128"];
          }) localPeers

      else
        # Regular peer: connect to hub (if has key)
        lib.optional myHubHasKey {
          PublicKey = myHubPeer.publicKey;
          AllowedIPs = net.allSubnets4 ++ net.allSubnets6;
          Endpoint = "${myHubPeer.endpoint}:${toString port}";
          PersistentKeepalive = 25;
        };

    # Collect warnings for missing credentials
    missingKeyWarnings = let
      peersWithoutKeys = lib.filterAttrs (n: p: p.publicKey or null == null) net.peers;
      peerNames = lib.attrNames peersWithoutKeys;
    in
      lib.optional (peerNames != [])
        "WireGuard: peers missing publicKey (run 'pki provision'): ${lib.concatStringsSep ", " peerNames}";

    endpointWarnings =
      lib.optional (isHub && rootHub.endpoint or null == null && !isRootHub)
        "WireGuard: root hub '${rootHubName}' has no endpoint configured";

  in {
    warnings = missingKeyWarnings ++ endpointWarnings;

    systemd.network = {
      netdevs."30-wg0" = {
        netdevConfig = {
          Name = "wg0";
          Kind = "wireguard";
        };
        wireguardConfig = {
          PrivateKeyFile = "/etc/secrets/wireguard/private.key";
        } // lib.optionalAttrs isHub {
          ListenPort = port;
        };
        inherit wireguardPeers;
      };

      networks."30-wg0" = {
        matchConfig.Name = "wg0";
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
      trustedInterfaces = ["wg0"];
    } // lib.optionalAttrs isHub {
      allowedUDPPorts = [port];
    };

    systemd.network.wait-online.ignoredInterfaces = ["wg0"];
  };
}
