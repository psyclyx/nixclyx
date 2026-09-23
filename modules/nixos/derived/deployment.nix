{config, lib, options, ...}: let
  eg = config.psyclyx.egregore;
  hostName = config.networking.hostName;
  thisHost = eg.entities.${hostName} or null;
  targetPort = if thisHost != null
    then thisHost.exposures.ssh.port or 22
    else 22;
in {
  config =
    if options ? deployment
    then lib.mkIf (thisHost != null) {
      deployment.targetPort = targetPort;
    }
    else {};
}
