# Egregore → distributed-builds infraZone projection.
#
# Reads the fleet's `infra` network entity to feed its zoneName into
# the generic distributed-builds module's `infraZone` option. The
# generic module composes `<host>.<infraZone>` for builder SSH hosts.
{config, lib, ...}: let
  eg = config.psyclyx.egregore;
  infra = eg.entities.infra or null;
  zoneName = if infra != null then infra.attrs.zoneName or "" else "";
in lib.mkIf (zoneName != "") {
  psyclyx.nixos.system.distributed-builds.infraZone = lib.mkDefault zoneName;
}
