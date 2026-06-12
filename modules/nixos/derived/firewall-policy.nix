# Egregore data → nftables zones + forward rules.
#
# Two emissions, both driven by fleet data:
#
# 1. **Zones.** For every network entity this host has an interface
#    on (`host.interfaces.<network>`), add that interface's device to
#    the network's zone (`network.zone`). Hosts don't restate the
#    zone→interface mapping; it falls out of declaring "I have an
#    interface for this network."
#
# 2. **Forward rules.** From the symmetric matrix in
#    `globals.policy.<src>.<dst>`. A rule is emitted only when *both*
#    zones end up declared on this host (so a gateway sees the slice
#    of policy it can enforce, and a non-routing host sees none).
#
# Interfaces that don't correspond to a network entity (the untagged
# trunk parent, WAN VLAN sub-iface, mullvad veth, etc.) are still
# host-declared via `firewall.zones.<zone>.interfaces`; NixOS option
# merging unions host-declared and projection-emitted entries.
{ config, lib, ... }:
let
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host or null;
  entities = eg.entities or {};
  policy = eg.policy or {};

  me = lib.attrByPath ["entities" hostname "host"] null eg;

  # Zone → list of interface devices, derived from
  # network.zone + host.interfaces.
  derivedZoneInterfaces =
    if me == null then {}
    else lib.foldl' (acc: netName:
      let
        netEnt = entities.${netName} or null;
        zone = lib.attrByPath ["network" "zone"] "" netEnt;
        device = (me.interfaces.${netName} or { device = ""; }).device;
      in
      if zone == "" || device == "" then acc
      else acc // { ${zone} = (acc.${zone} or []) ++ [device]; }
    ) {} (lib.attrNames (me.interfaces or {}));


  # The merged view (derived + host-declared) is what we read for
  # forward-rule emission. config.<...>.firewall.zones is the
  # merged-options result; reading it here picks up both the
  # projection's contribution and host overrides.
  fw = config.psyclyx.nixos.network.firewall;

  forwardRules = lib.concatLists (
    lib.mapAttrsToList (src: dsts:
      lib.concatLists (lib.mapAttrsToList (dst: action:
        lib.optional (
          action == "accept"
          && (fw.zones ? ${src})
          && (fw.zones ? ${dst})
        ) { from = src; to = dst; }
      ) dsts)
    ) policy
  );
in {
  config = lib.mkMerge [
    # Emit derived zones whenever the host has any network-tied
    # interfaces. Empty zone lists are harmless under NixOS merge.
    (lib.mkIf (derivedZoneInterfaces != {}) {
      psyclyx.nixos.network.firewall.zones =
        lib.mapAttrs (_: ifaces: { interfaces = ifaces; })
          derivedZoneInterfaces;
    })

    # Emit forward rules when both src and dst zones are reachable
    # via this host. Triggered after zone merge (one eval pass).
    (lib.mkIf (forwardRules != []) {
      psyclyx.nixos.network.firewall.forward = forwardRules;
    })
  ];
}
