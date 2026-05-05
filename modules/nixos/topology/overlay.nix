# Overlay → underlay routing projection.
#
# For each network entity that declares `network.underlay.<site> =
# <underlayNetworkName>`, every host in that site that has an address
# on the underlay installs /32 host routes for its same-site overlay
# peers, with next-hop set to each peer's underlay address.
#
# Why every-host and not just the gateway:
#
# Forwarding the shortcut through the gateway (sigil → iyr → lab-1)
# breaks under stateful conntrack: the destination replies directly via
# the underlay LAN (asymmetric path), so the gateway's conntrack never
# observes the SYN-ACK and marks subsequent packets INVALID. Installing
# the route on every site host makes apt-internal overlay traffic skip
# the gateway entirely — sigil ARPs lab-1's MAC and frames go straight
# over the LAN, no router in the path, no asymmetry.
#
# Routes attach to the systemd-networkd unit that owns the underlay
# interface. That unit's prefix differs depending on whether this host
# uses the gateway projection (`31-*` from network/gateway.nix) or the
# generic interface projection (`20-*` from network/interfaces.nix).
{
  config,
  lib,
  ...
}:
let
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host or null;
  me = if hostname != null then eg.entities.${hostname} or null else null;
  amHost = me != null && me.type == "host";

  isGateway = config.psyclyx.nixos.network.gateway.enable or false;
  unitPrefix = if isGateway then "31" else "20";

  mySite = if amHost then me.host.site or null else null;

  overlays = lib.filterAttrs (_: e: e.type == "network") eg.entities;

  # For an overlay that has an underlay declared at this site, emit the
  # shortcut routes if this host has an address on that underlay.
  shortcutForOverlay =
    overlayName: overlayEntity:
    let
      underlayName = overlayEntity.network.underlay.${mySite} or null;
      underlayEntity =
        if underlayName != null then eg.entities.${underlayName} or null else null;

      # Local-side gate: this host is "on" the underlay if it declares
      # an interface for it. Whether the address is static or DHCP
      # doesn't matter — the routes use peer addresses, not ours.
      myUnderlayDevice =
        if amHost && underlayName != null then
          me.host.interfaces.${underlayName}.device or null
        else
          null;

      ready =
        underlayEntity != null
        && underlayEntity.type == "network"
        && myUnderlayDevice != null;

      # Peers in this site with addresses on both networks. Exclude self
      # (a host doesn't need a route to its own overlay address).
      sitePeers = lib.filterAttrs (
        peerName: h:
        peerName != hostname
        && h.type == "host"
        && (h.host.site or null) == mySite
        && h.host.addresses ? ${overlayName}
        && (h.host.addresses.${overlayName}.ipv4 or null) != null
        && h.host.addresses ? ${underlayName}
        && (h.host.addresses.${underlayName}.ipv4 or null) != null
      ) eg.entities;

      mkRoute = _: h: {
        Destination = "${h.host.addresses.${overlayName}.ipv4}/32";
        Gateway = h.host.addresses.${underlayName}.ipv4;
      };
    in
    if !ready then
      { }
    else
      {
        unit = "${unitPrefix}-${myUnderlayDevice}";
        routes = lib.mapAttrsToList mkRoute sitePeers;
      };

  shortcuts = lib.filter (s: s != { } && s.routes != [ ]) (
    lib.mapAttrsToList shortcutForOverlay overlays
  );

  routesByUnit = lib.foldl' (
    acc: s: acc // { ${s.unit} = (acc.${s.unit} or [ ]) ++ s.routes; }
  ) { } shortcuts;

  enabled = amHost && mySite != null && shortcuts != [ ];
in
{
  config = lib.mkIf enabled {
    systemd.network.networks = lib.mapAttrs (_: routes: { inherit routes; }) routesByUnit;
  };
}
