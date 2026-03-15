lib: topo:
let
  enriched = import ./topology.nix lib topo;

  hosts = topo.hosts;
  haGroups = topo.haGroups;

  hostAddress = hostname: network:
    enriched.hostAddress4 network hosts.${hostname};

  hostAddress6 = hostname: network:
    enriched.hostAddress6 network hosts.${hostname};

  leader = nodeList:
    builtins.head (builtins.sort builtins.lessThan nodeList);

  groupVip = groupName:
    if haGroups.${groupName} ? vip
    then haGroups.${groupName}.vip.ipv4
    else let
      net = enriched.networks.${haGroups.${groupName}.network};
    in "${net.prefix}.${toString haGroups.${groupName}.vipOffset}";

  groupVip6 = groupName:
    if haGroups.${groupName} ? vip && haGroups.${groupName}.vip ? ipv6
    then haGroups.${groupName}.vip.ipv6
    else null;

  # Priority from list position: first member = 99, second = 98, etc.
  memberPriority = groupName: hostname:
    let
      members = haGroups.${groupName}.members;
      idx = lib.lists.findFirstIndex (m: m == hostname)
        (throw "${hostname} is not a member of group ${groupName}")
        members;
    in 100 - (idx + 1);

  groupVrid = groupName:
    let g = haGroups.${groupName};
    in if g.vrid != null then g.vrid
    else if g.vipOffset != null then g.vipOffset
    else throw "HA group '${groupName}' has neither vrid nor vipOffset set.";

  managedHosts = lib.sort builtins.lessThan
    (lib.attrNames (lib.filterAttrs (_: host: host.mac != {}) hosts));

  managedHostsOnNetwork = networkName:
    builtins.filter (name: hosts.${name}.interfaces ? ${networkName}) managedHosts;

  network = name: enriched.networks.${name};
  networkPrefix = name: enriched.networks.${name}.prefix;
  networkPrefixLen = name: enriched.networks.${name}.prefixLen;

  hostInterface = hostname: networkName:
    let
      iface = hosts.${hostname}.interfaces.${networkName} or null;
    in
      if iface == null then networkName
      else if iface.bond or null != null then iface.bond
      else iface.device or networkName;

  hostMacForNetwork = hostname: networkName:
    let
      iface = hosts.${hostname}.interfaces.${networkName};
      physDev =
        if iface.device or null != null then iface.device
        else builtins.head iface.members;
    in hosts.${hostname}.mac.${physDev};

  # Returns "tpm", "transit" (peer in same HA group has TPM), or "shamir".
  unsealMethod = hostname:
    let
      host = hosts.${hostname};
      hasTpm = host.hardware.tpm or false;
      memberGroups = lib.filterAttrs (_: g:
        builtins.elem hostname (g.members or [])
      ) haGroups;
      peerHasTpm = builtins.any (g:
        builtins.any (m: m != hostname && (hosts.${m}.hardware.tpm or false)) g.members
      ) (builtins.attrValues memberGroups);
    in
      if hasTpm then "tpm"
      else if peerHasTpm then "transit"
      else "shamir";

in {
  inherit hostAddress hostAddress6;
  inherit leader;
  inherit groupVip groupVip6 groupVrid memberPriority;
  inherit managedHosts managedHostsOnNetwork;
  inherit network networkPrefix networkPrefixLen;
  inherit hostInterface hostMacForNetwork;
  inherit unsealMethod;

  inherit hosts haGroups;
  domains = topo.domains;
  wireguard = topo.wireguard;
  conventions = topo.conventions;
  networks = enriched.networks;
  utils = enriched.utils;
  inherit enriched;
}
