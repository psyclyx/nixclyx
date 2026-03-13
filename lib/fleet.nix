lib: topo:
let
  enriched = import ./topology.nix lib topo;

  hosts = topo.hosts;
  haGroups = topo.haGroups;

  # Address resolution — delegates to enriched lib which checks explicit
  # addresses first, falls back to convention math during migration.
  hostAddress = hostname: network:
    enriched.hostAddress4 network hosts.${hostname};

  hostAddress6 = hostname: network:
    enriched.hostAddress6 network hosts.${hostname};

  # Deterministic leader election — first hostname alphabetically.
  leader = nodeList:
    builtins.head (builtins.sort builtins.lessThan nodeList);

  # HA VIP resolution — prefers explicit vip, falls back to vipOffset.
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

  # HA member priority derived from list position.
  # First member gets highest priority (99), each subsequent gets 1 less.
  memberPriority = groupName: hostname:
    let
      members = haGroups.${groupName}.members;
      len = builtins.length members;
      indices = lib.genList (i: i) len;
      found = builtins.filter (i: builtins.elemAt members i == hostname) indices;
      idx = if found == []
        then throw "${hostname} is not a member of group ${groupName}"
        else builtins.head found;
    in 100 - (idx + 1);

  # HA VRRP ID.
  groupVrid = groupName:
    let g = haGroups.${groupName};
    in if g.vrid != null then g.vrid
    else if g.vipOffset != null then g.vipOffset
    else throw "HA group '${groupName}' has neither vrid nor vipOffset set.";

  # Network queries — returns enriched network data.
  network = name: enriched.networks.${name};
  networkPrefix = name: enriched.networks.${name}.prefix;
  networkPrefixLen = name: enriched.networks.${name}.prefixLen;

  # Resolve the systemd-networkd interface name for a host on a network.
  hostInterface = hostname: networkName:
    let
      iface = hosts.${hostname}.interfaces.${networkName} or null;
    in
      if iface == null then networkName
      else if iface.bond or null != null then iface.bond
      else iface.device or networkName;

  # Resolve the physical MAC used for DHCP identification on a network.
  hostMacForNetwork = hostname: networkName:
    let
      iface = hosts.${hostname}.interfaces.${networkName};
      physDev =
        if iface.device or null != null then iface.device
        else builtins.head iface.members;
    in hosts.${hostname}.mac.${physDev};

in {
  inherit hostAddress hostAddress6;
  inherit leader;
  inherit groupVip groupVip6 groupVrid memberPriority;
  inherit network networkPrefix networkPrefixLen;
  inherit hostInterface hostMacForNetwork;

  # Direct data access
  inherit hosts haGroups;
  domains = topo.domains;
  wireguard = topo.wireguard;
  conventions = topo.conventions;

  # Enriched network data
  networks = enriched.networks;

  # DNS utilities (intToHex, reverse nibbles, etc.)
  utils = enriched.utils;

  # Unseal strategy — derives from hardware capabilities.
  # Returns "tpm" if host has TPM, "transit" if another host in the same
  # HA group has TPM (can use transit unseal via that host), else "shamir".
  unsealMethod = hostname:
    let
      host = hosts.${hostname};
      hasTpm = host.hardware.tpm or false;
      # Find HA groups this host belongs to.
      memberGroups = lib.filterAttrs (_: g:
        builtins.elem hostname (g.members or [])
      ) haGroups;
      # Check if any peer in those groups has a TPM.
      peerHasTpm = builtins.any (g:
        builtins.any (m: m != hostname && (hosts.${m}.hardware.tpm or false)) g.members
      ) (builtins.attrValues memberGroups);
    in
      if hasTpm then "tpm"
      else if peerHasTpm then "transit"
      else "shamir";

  # Full enriched lib (backward compat during migration)
  inherit enriched;
}
