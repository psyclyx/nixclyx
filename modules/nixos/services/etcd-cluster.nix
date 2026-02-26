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
      topo = config.psyclyx.topology;
      topoLib = topo.enriched;
      hostname = config.psyclyx.nixos.host;
      labIdx = topo.hosts.${hostname}.labIndex;

      dataNet = topoLib.networks.${cfg.dataNetwork};
      bindAddr = "${dataNet.prefix}.${toString (topo.conventions.hostBaseOffset + labIdx)}";

      memberAddr = name: let
        idx = topo.hosts.${name}.labIndex;
      in "${dataNet.prefix}.${toString (topo.conventions.hostBaseOffset + idx)}";

      initialCluster = map (name:
        "${name}=http://${memberAddr name}:${toString cfg.peerPort}"
      ) cfg.clusterNodes;
    in
    {
      services.etcd = {
        enable = true;
        name = hostname;
        listenClientUrls = [
          "http://${bindAddr}:${toString cfg.clientPort}"
          "http://127.0.0.1:${toString cfg.clientPort}"
        ];
        advertiseClientUrls = [
          "http://${bindAddr}:${toString cfg.clientPort}"
        ];
        listenPeerUrls = [
          "http://${bindAddr}:${toString cfg.peerPort}"
        ];
        initialAdvertisePeerUrls = [
          "http://${bindAddr}:${toString cfg.peerPort}"
        ];
        inherit initialCluster;
        initialClusterToken = cfg.clusterToken;
        initialClusterState = "new";
        openFirewall = true;
      };
    };
}
