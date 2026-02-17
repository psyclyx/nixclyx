{config, lib, ...}: let
  topo = config.psyclyx.topology;
  hostName = config.networking.hostName;
  thisHost = topo.hosts.${hostName} or null;
in {
  config = lib.mkIf (thisHost != null) {
    deployment.targetPort = thisHost.sshPort;
  };
}
