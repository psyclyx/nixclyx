{
  config,
  lib,
  pkgs,
  ...
}: let
  topo = config.psyclyx.topology;
  hostName = config.networking.hostName;
  thisHost = topo.hosts.${hostName} or null;
  hasWg = thisHost != null && thisHost.wireguard != null;

  hubHost = topo.hosts.${topo.wireguard.hub};
  isHub = hasWg && hostName == topo.wireguard.hub;

  wgPeers = lib.filterAttrs (name: host:
    name != hostName && host.wireguard != null
  ) topo.hosts;

  allPeerExportedRoutes = lib.concatMap
    (host: host.wireguard.exportedRoutes)
    (lib.attrValues wgPeers);

  # Hub endpoint: prefer explicit endpoint from host data, fall back to constructed
  hubEndpoint =
    if hubHost.wireguard.endpoint != null
    then hubHost.wireguard.endpoint
    else "vpn.${topo.domains.public}:${toString topo.wireguard.port}";

  privateKeyPath = "/etc/secrets/wireguard/private.key";
in {
  options.psyclyx.nixos.wireguard.autoGenerateKeys = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    description = "WireGuard private key paths to auto-generate if missing.";
  };

  config = lib.mkIf hasWg {
    psyclyx.nixos.wireguard.autoGenerateKeys = lib.mkDefault [privateKeyPath];
    psyclyx.nixos.network.ports.wireguard = {udp = [topo.wireguard.port];};

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
        if [ ! -f "${keyPath}" ] || [ ! -s "${keyPath}" ]; then
          echo "Generating WireGuard key: ${keyPath}"
          umask 027
          mkdir -p "$(dirname "${keyPath}")"
          ${wg} genkey > "${keyPath}"
          chown root:systemd-network "${keyPath}"
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
          (lib.mkIf isHub {ListenPort = topo.wireguard.port;})
        ];

        wireguardPeers =
          if isHub
          then
            lib.mapAttrsToList (_: host: {
              PublicKey = host.wireguard.publicKey;
              AllowedIPs = ["${host.addresses.vpn.ipv4}/32"] ++ host.wireguard.exportedRoutes;
            })
            wgPeers
          else [
              {
                PublicKey = hubHost.wireguard.publicKey;
                Endpoint = hubEndpoint;
                AllowedIPs = [topo.wireguard.subnet] ++ allPeerExportedRoutes;
                PersistentKeepalive = 25;
              }
            ];
      };

      networks."30-wg0" = lib.mkMerge [
        {
          matchConfig.Name = "wg0";
          address = let
            wgPrefixLen = builtins.elemAt (lib.splitString "/" topo.wireguard.subnet) 1;
          in ["${thisHost.addresses.vpn.ipv4}/${wgPrefixLen}"];
        }
        (lib.mkIf (!isHub) {
          dns = [hubHost.addresses.vpn.ipv4];
          domains = ["~${topo.domains.internal}"];
        })
        (lib.mkIf isHub {
          routes = lib.concatMap (host:
            map (route: { Destination = route; })
                (host.wireguard.exportedRoutes or [])
          ) (lib.attrValues wgPeers);
        })
      ];
    };
  };
}
