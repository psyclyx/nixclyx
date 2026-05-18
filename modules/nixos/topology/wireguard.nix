{config, lib, pkgs, ...}: let
  eg = config.psyclyx.egregore;
  hostName = config.networking.hostName;
  me = eg.entities.${hostName} or null;
  hasWg = me != null && me.type == "host" && me.host.wireguard != null;

  # Overlay topology comes from the vpn network entity + its hub host.
  vpnNet = eg.entities.vpn;
  vpnSubnet = vpnNet.network.ipv4;
  hubName = vpnNet.attrs.gatewayRef;
  hub = eg.entities.${hubName};
  hubPort = hub.host.wireguard.port;
  isHub = hasWg && hostName == hubName;

  # Does this host's site have a local DNS server (refs.dns)?
  hasLocalSiteDns = let
    mySiteName = if me != null && me.type == "host" then me.host.site or null else null;
    mySite = if mySiteName != null then eg.entities.${mySiteName} or null else null;
  in mySite != null && mySite.type == "site" && mySite.refs ? dns;

  wgPeers = lib.filterAttrs (name: e:
    name != hostName && e.type == "host" && e.host.wireguard != null
  ) eg.entities;

  allPeerExportedRoutes = lib.concatMap
    (e: e.host.wireguard.exportedRoutes)
    (lib.attrValues wgPeers);

  resolvedAllowedIPs =
    if me.host.wireguard.allowedNetworks != null
    then
      [vpnSubnet]
      ++ map (name: eg.entities.${name}.network.ipv4) me.host.wireguard.allowedNetworks
    else
      [vpnSubnet] ++ allPeerExportedRoutes;

  hubEndpoint =
    if hub.host.wireguard.endpoint != null
    then hub.host.wireguard.endpoint
    else "vpn.${eg.domains.public}:${toString hubPort}";

  privateKeyPath = "/etc/secrets/wireguard/private.key";
in {
  options.psyclyx.nixos.wireguard.autoGenerateKeys = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    description = "WireGuard private key paths to auto-generate if missing.";
  };

  config = lib.mkIf hasWg {
    psyclyx.nixos.wireguard.autoGenerateKeys = lib.mkDefault [privateKeyPath];
    psyclyx.nixos.network.ports.wireguard = {udp = [hubPort];};

    systemd.services.wireguard-keygen = {
      description = "Auto-generate WireGuard private keys";
      wantedBy = ["multi-user.target"];
      before = ["systemd-networkd.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = let
        wg = "${pkgs.wireguard-tools}/bin/wg";
        keys = config.psyclyx.nixos.wireguard.autoGenerateKeys;
      in lib.concatMapStringsSep "\n" (keyPath: ''
        keyDir=$(dirname "${keyPath}")
        # Make sure every parent down to the keyDir is traversable
        # world-x (0755) so systemd-network can reach the secret. The
        # keyDir itself stays group-only (root:systemd-network 0750)
        # and the file gets group-only read (0640). mkdir -p uses
        # umask for new components, so set 022 explicitly.
        umask 022
        mkdir -p "$keyDir"
        chown root:systemd-network "$keyDir"
        chmod 0750 "$keyDir"
        if [ ! -f "${keyPath}" ] || [ ! -s "${keyPath}" ]; then
          echo "Generating WireGuard key: ${keyPath}"
          (umask 027; ${wg} genkey > "${keyPath}")
          chown root:systemd-network "${keyPath}"
          chmod 0640 "${keyPath}"
        fi
      '') keys;
    };

    systemd.network = {
      netdevs."30-wg0" = {
        netdevConfig = {
          Kind = "wireguard";
          Name = "wg0";
        };

        wireguardConfig = lib.mkMerge [
          {PrivateKeyFile = privateKeyPath;}
          (lib.mkIf isHub {ListenPort = hubPort;})
        ];

        wireguardPeers =
          if isHub
          then
            lib.mapAttrsToList (_: e: {
              PublicKey = e.host.wireguard.publicKey;
              AllowedIPs = ["${e.host.addresses.vpn.ipv4}/32"] ++ e.host.wireguard.exportedRoutes;
            }) wgPeers
          else [
            {
              PublicKey = hub.host.wireguard.publicKey;
              Endpoint = hubEndpoint;
              AllowedIPs = resolvedAllowedIPs;
              PersistentKeepalive = 25;
            }
          ];
      };

      networks."30-wg0" = lib.mkMerge [
        {
          matchConfig.Name = "wg0";
          address = let
            wgPrefixLen = toString vpnNet.attrs.prefixLen;
          in ["${me.host.addresses.vpn.ipv4}/${wgPrefixLen}"];
        }
        # Only set WG DNS for road warriors (no site or no local DNS server).
        # Site hosts use the local resolver which handles cross-site forwarding.
        (lib.mkIf (!isHub && !hasLocalSiteDns) {
          dns = [hub.host.addresses.vpn.ipv4];
          domains = ["~${eg.domains.internal}"];
        })
        (lib.mkIf isHub {
          routes = lib.concatMap (e:
            map (route: { Destination = route; })
                (e.host.wireguard.exportedRoutes or [])
          ) (lib.attrValues wgPeers);
        })
      ];
    };
  };
}
