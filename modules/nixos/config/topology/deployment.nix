{config, lib, options, ...}: let
  topo = config.psyclyx.topology;
  hostName = config.networking.hostName;
  thisHost = topo.hosts.${hostName} or null;
  targetPort = if thisHost != null then thisHost.sshPort else 22;
in {
  config =
    if options ? deployment
    then lib.mkIf (thisHost != null) {
      deployment.targetPort = targetPort;
    }
    else {};
}
