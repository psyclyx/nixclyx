# Egregore → openssh port projection.
#
# Reads this host's `ssh` exposure to feed the generic openssh
# module's `port` option. Hosts without the entity or the exposure
# fall back to the option's own default (22).
{config, lib, ...}: let
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;
  me = eg.entities.${hostname} or null;
in lib.mkIf (me != null) {
  psyclyx.nixos.services.openssh.port = lib.mkDefault me.exposures.ssh.port;
}
