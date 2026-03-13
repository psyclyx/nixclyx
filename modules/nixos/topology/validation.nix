{
  config,
  lib,
  ...
}: let
  topo = config.psyclyx.topology;

  hosts = topo.hosts;
  networks = topo.networks;
  haGroups = topo.haGroups;

  # Collect all (hostname, network, ipv4) triples.
  allAddresses = lib.concatLists (lib.mapAttrsToList (hostname: host:
    lib.mapAttrsToList (netName: addr: {
      inherit hostname netName;
      ipv4 = addr.ipv4;
    }) (lib.filterAttrs (_: a: a.ipv4 or null != null) (host.addresses or {}))
  ) hosts);

  # Group by network, then check for duplicate IPv4 within each network.
  addressesByNetwork = builtins.groupBy (a: a.netName) allAddresses;
  duplicateChecks = lib.concatLists (lib.mapAttrsToList (netName: addrs: let
    ipv4s = map (a: a.ipv4) addrs;
    unique = lib.unique ipv4s;
    hasDupes = builtins.length ipv4s != builtins.length unique;
  in lib.optional hasDupes {
    assertion = false;
    message = "Duplicate IPv4 addresses on network '${netName}': ${builtins.toJSON ipv4s}";
  }) addressesByNetwork);

  # HA group members must exist in hosts.
  haGroupMemberChecks = lib.concatLists (lib.mapAttrsToList (groupName: group:
    map (member: {
      assertion = hosts ? ${member};
      message = "HA group '${groupName}' references non-existent host '${member}'.";
    }) group.members
  ) haGroups);

  # HA VIPs must not collide with host addresses on the same network.
  haVipCollisionChecks = lib.concatLists (lib.mapAttrsToList (groupName: group: let
    vipIpv4 = if group.vip or null != null then group.vip.ipv4 else null;
    netName = group.network;
    hostAddrsOnNet = lib.concatLists (lib.mapAttrsToList (hostname: host:
      if host.addresses ? ${netName} && host.addresses.${netName}.ipv4 or null != null
      then [{ inherit hostname; ipv4 = host.addresses.${netName}.ipv4; }]
      else []
    ) hosts);
    collision = lib.findFirst (a: a.ipv4 == vipIpv4) null hostAddrsOnNet;
  in lib.optional (vipIpv4 != null && collision != null) {
    assertion = false;
    message = "HA group '${groupName}' VIP ${vipIpv4} collides with host '${collision.hostname}' on network '${netName}'.";
  }) haGroups);

  # HA group networks must exist.
  haNetworkChecks = lib.mapAttrsToList (groupName: group: {
    assertion = networks ? ${group.network};
    message = "HA group '${groupName}' references non-existent network '${group.network}'.";
  }) haGroups;

  # WireGuard peers must have a VPN address.
  wgPeerChecks = lib.concatLists (lib.mapAttrsToList (hostname: host:
    lib.optional (host.wireguard or null != null && !(host.addresses ? vpn)) {
      assertion = false;
      message = "Host '${hostname}' has WireGuard config but no addresses.vpn entry.";
    }
  ) hosts);

  # Container/VM hosts must have a valid parent.
  parentChecks = lib.concatLists (lib.mapAttrsToList (hostname: host:
    lib.optional (host.parent or null != null && !(hosts ? ${host.parent})) {
      assertion = false;
      message = "Host '${hostname}' references non-existent parent '${host.parent}'.";
    }
  ) hosts);

  # Firewall zone validation — zone names in input/forward/masquerade must exist in zones.
  fwCfg = config.psyclyx.nixos.network.firewall or null;
  zoneNames = if fwCfg != null && fwCfg ? zones then lib.attrNames fwCfg.zones else [];
  inputZoneChecks = if fwCfg != null && fwCfg ? input
    then map (zoneName: {
      assertion = builtins.elem zoneName zoneNames;
      message = "Firewall input references non-existent zone '${zoneName}'. Defined zones: ${builtins.toJSON zoneNames}";
    }) (lib.attrNames (fwCfg.input or {}))
    else [];
  forwardZoneChecks = if fwCfg != null && fwCfg ? forward
    then lib.concatMap (rule: [
      {
        assertion = builtins.elem (rule.from or "") zoneNames;
        message = "Firewall forward references non-existent zone '${rule.from or ""}'. Defined zones: ${builtins.toJSON zoneNames}";
      }
      {
        assertion = builtins.elem (rule.to or "") zoneNames;
        message = "Firewall forward references non-existent zone '${rule.to or ""}'. Defined zones: ${builtins.toJSON zoneNames}";
      }
    ]) (fwCfg.forward or [])
    else [];
in {
  config.assertions =
    duplicateChecks
    ++ haGroupMemberChecks
    ++ haVipCollisionChecks
    ++ haNetworkChecks
    ++ wgPeerChecks
    ++ parentChecks
    ++ inputZoneChecks
    ++ forwardZoneChecks;
}
