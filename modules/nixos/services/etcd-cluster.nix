{
  path = [
    "psyclyx"
    "nixos"
    "services"
    "etcd-cluster"
  ];
  description = "etcd cluster for distributed consensus";
  options =
    { lib, ... }:
    {
      clusterNodes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Hostnames of all nodes in the etcd cluster.";
      };
      dataNetwork = lib.mkOption {
        type = lib.types.str;
        default = "data";
        description = "Topology network name for data traffic.";
      };
      clientPort = lib.mkOption {
        type = lib.types.port;
        default = 2379;
        description = "Port for etcd client connections.";
      };
      peerPort = lib.mkOption {
        type = lib.types.port;
        default = 2380;
        description = "Port for etcd peer communication.";
      };
      clusterToken = lib.mkOption {
        type = lib.types.str;
        default = "psyclyx-etcd";
        description = "Initial cluster token for bootstrapping.";
      };
    };

  config =
    {
      cfg,
      config,
      lib,
      ...
    }:
    let
      fleet = config.psyclyx.fleet;
      hostname = config.psyclyx.nixos.host;

      bindAddr = fleet.hostAddress hostname cfg.dataNetwork;

      memberAddr = name: fleet.hostAddress name cfg.dataNetwork;

      initialCluster = map (name:
        "${name}=http://${memberAddr name}:${toString cfg.peerPort}"
      ) cfg.clusterNodes;
    in
    {
      services.etcd = {
        enable = true;
        name = hostname;
        listenClientUrls = [
          "https://${bindAddr}:${toString cfg.clientPort}"
          "https://127.0.0.1:${toString cfg.clientPort}"
        ];
        advertiseClientUrls = [
          "https://${bindAddr}:${toString cfg.clientPort}"
        ];
        listenPeerUrls = [
          "https://${bindAddr}:${toString cfg.peerPort}"
        ];
        initialAdvertisePeerUrls = [
          "https://${bindAddr}:${toString cfg.peerPort}"
        ];
        inherit initialCluster;
        initialClusterToken = cfg.clusterToken;
        initialClusterState = "new";
      };

      psyclyx.nixos.network.ports.etcd = [cfg.clientPort cfg.peerPort];
    };
}
