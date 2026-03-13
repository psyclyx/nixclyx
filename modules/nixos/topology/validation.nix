{
  config,
  lib,
  ...
}: let
  topo = config.psyclyx.topology;

  hosts = topo.hosts;
  networks = topo.networks;
  haGroups = topo.haGroups;

  allAddresses = lib.concatLists (lib.mapAttrsToList (hostname: host:
    lib.mapAttrsToList (netName: addr: {
      inherit hostname netName;
      ipv4 = addr.ipv4;
    }) (lib.filterAttrs (_: a: a.ipv4 != null) host.addresses)
  ) hosts);

  addressesByNetwork = builtins.groupBy (a: a.netName) allAddresses;
  duplicateChecks = lib.concatLists (lib.mapAttrsToList (netName: addrs: let
    ipv4s = map (a: a.ipv4) addrs;
    unique = lib.unique ipv4s;
  in lib.optional (builtins.length ipv4s != builtins.length unique) {
    assertion = false;
    message = "Duplicate IPv4 addresses on network '${netName}': ${builtins.toJSON ipv4s}";
  }) addressesByNetwork);

  haGroupMemberChecks = lib.concatLists (lib.mapAttrsToList (groupName: group:
    map (member: {
      assertion = hosts ? ${member};
      message = "HA group '${groupName}' references non-existent host '${member}'.";
    }) group.members
  ) haGroups);

  haVipCollisionChecks = lib.concatLists (lib.mapAttrsToList (groupName: group: let
    vipIpv4 = group.vip.ipv4 or null;
    netName = group.network;
    hostAddrsOnNet = lib.concatLists (lib.mapAttrsToList (hostname: host:
      if host.addresses ? ${netName} && host.addresses.${netName}.ipv4 != null
      then [{ inherit hostname; ipv4 = host.addresses.${netName}.ipv4; }]
      else []
    ) hosts);
    collision = lib.findFirst (a: a.ipv4 == vipIpv4) null hostAddrsOnNet;
  in lib.optional (vipIpv4 != null && collision != null) {
    assertion = false;
    message = "HA group '${groupName}' VIP ${vipIpv4} collides with host '${collision.hostname}' on network '${netName}'.";
  }) haGroups);

  haNetworkChecks = lib.mapAttrsToList (groupName: group: {
    assertion = networks ? ${group.network};
    message = "HA group '${groupName}' references non-existent network '${group.network}'.";
  }) haGroups;

  wgPeerChecks = lib.concatLists (lib.mapAttrsToList (hostname: host:
    lib.optional (host.wireguard != null && !(host.addresses ? vpn)) {
      assertion = false;
      message = "Host '${hostname}' has WireGuard config but no addresses.vpn entry.";
    }
  ) hosts);

  parentChecks = lib.concatLists (lib.mapAttrsToList (hostname: host:
    lib.optional (host.parent != null && !(hosts ? ${host.parent})) {
      assertion = false;
      message = "Host '${hostname}' references non-existent parent '${host.parent}'.";
    }
  ) hosts);

  fwCfg = config.psyclyx.nixos.network.firewall or null;
  zoneNames = lib.attrNames (fwCfg.zones or {});
  inputZoneChecks = if fwCfg != null && fwCfg ? input
    then map (zoneName: {
      assertion = builtins.elem zoneName zoneNames;
      message = "Firewall input references non-existent zone '${zoneName}'.";
    }) (lib.attrNames fwCfg.input)
    else [];
  forwardZoneChecks = if fwCfg != null && fwCfg ? forward
    then lib.concatMap (rule: [
      {
        assertion = rule ? from && builtins.elem rule.from zoneNames;
        message = "Firewall forward references non-existent source zone '${rule.from or "?"}'.";
      }
      {
        assertion = rule ? to && builtins.elem rule.to zoneNames;
        message = "Firewall forward references non-existent destination zone '${rule.to or "?"}'.";
      }
    ]) fwCfg.forward
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
