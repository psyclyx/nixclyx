# Fleet projection: an iLO node + the graph → desired BMC state.
{ config, lib, egregore, egregorLib, deviceName, ... }:
let
  top = egregore;
  entity = top.entities.${deviceName};
  name = deviceName;
  ilo = entity.ilo;

  mgmtNet = top.entities.${ilo.mgmtNetwork} or null;
  zoneName = if mgmtNet != null then mgmtNet.attrs.zoneName or null else null;
  derivedHostname = if zoneName != null then "${name}.${zoneName}" else name;
  resolvedHostname =
    if ilo.address != null then ilo.address
    else if ilo.hostname != null then ilo.hostname
    else derivedHostname;

  hostEntity = let h = entity.refs.host or null; in
    if h != null then top.entities.${h} or null else null;
  hostBoot = if hostEntity != null then hostEntity.host.boot else { };
  seats = hostBoot.firmwareNics or { };
  pxeSeats = builtins.filter (n: seats ? ${n}) (hostBoot.pxeInterfaces or [ ]);

  spec = {
    network_boot.pxe = map (n: { inherit (seats.${n}) adapter port; }) pxeSeats;
    # Pin PXE to IPv4 for hosts that netboot; firmware "Auto" was
    # observed picking the IPv6 entry, which the fleet does not serve.
    bios = lib.optionalAttrs ((hostBoot.mode or "local") == "pxe") {
      UefiPxeBoot = "IPv4";
    };
  };
in {
  ilo.model = ilo.model;
  ilo.address = resolvedHostname;
  ilo.spec = spec;
}
