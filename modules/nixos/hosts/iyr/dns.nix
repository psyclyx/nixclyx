{
  config,
  lib,
  ...
}: let
  topo = config.psyclyx.topology;
  dt = topo.enriched;
  conventions = topo.conventions;

  labServers = lib.sort (a: b: a.n < b.n) (lib.mapAttrsToList (name: host: {
    inherit name;
    n = host.labIndex;
    ifaces = host.interfaces;
  }) (lib.filterAttrs (_: host: host.labIndex != null) topo.hosts));

  # Lab servers that have an interface on a given network.
  labServersOnNetwork = networkName:
    builtins.filter (s: s.ifaces ? ${networkName}) labServers;

  # Derive VIP A records for haGroups on a given network.
  vipRecordsForNetwork = networkName: let
    net = dt.networks.${networkName};
    groups = lib.filterAttrs (_: g: g.network == networkName) topo.haGroups;
  in
    lib.concatStringsSep "\n" (lib.mapAttrsToList (groupName: group:
      "${groupName}-vip IN A ${net.prefix}.${toString group.vipOffset}"
    ) groups);

  # Build a forward zone file for a VLAN's network.
  mkForwardZoneData = vlanId: let
    name = dt.vlanNameMap.${toString vlanId};
    net = dt.networks.${name};
    prefix6 = "${topo.ipv6UlaPrefix}:${net.vlanHex}";
    servers = labServersOnNetwork name;
    serverRecords = lib.concatMapStringsSep "\n" (s:
      "${s.name} IN A ${net.prefix}.${toString (conventions.hostBaseOffset + s.n)}\n" +
      "${s.name} IN AAAA ${prefix6}::${dt.utils.intToHex (conventions.hostBaseOffset + s.n)}"
    ) servers;
    vipRecords = vipRecordsForNetwork name;
  in {
    name = net.zoneName;
    value = {
      ddns = true;
      data = ''
        $ORIGIN ${net.zoneName}.
        $TTL 300
        @    IN SOA  ns1.${net.zoneName}. admin.${net.zoneName}. (
                     1 3600 900 604800 300 )
        @    IN NS   ns1.${net.zoneName}.
        ns1  IN A    ${net.gateway4}
        iyr  IN A    ${net.gateway4}
        iyr  IN AAAA ${net.gateway6}
        ${serverRecords}
        ${vipRecords}
      '';
    };
  };

  # Build a reverse (PTR) zone file for a VLAN's IPv4 network.
  mkReverseZoneData = vlanId: let
    name = dt.vlanNameMap.${toString vlanId};
    net = dt.networks.${name};
    octets = lib.splitString "." net.prefix;
    reverseZone = "${lib.concatStringsSep "." (lib.reverseList octets)}.in-addr.arpa";
    servers = labServersOnNetwork name;
    serverPtrs = lib.concatMapStringsSep "\n" (s:
      "${toString (conventions.hostBaseOffset + s.n)} IN PTR ${s.name}.${net.zoneName}."
    ) servers;
  in {
    name = reverseZone;
    value = {
      ddns = true;
      data = ''
        $ORIGIN ${reverseZone}.
        $TTL 300
        @    IN SOA  ns1.${net.zoneName}. admin.${net.zoneName}. (
                     1 3600 900 604800 300 )
        @    IN NS   ns1.${net.zoneName}.
        ${toString conventions.gatewayOffset} IN PTR iyr.${net.zoneName}.
        ${serverPtrs}
      '';
    };
  };

  # Build a reverse (PTR) zone file for a VLAN's IPv6 ULA network.
  mkIp6ReverseZoneData = vlanId: let
    name = dt.vlanNameMap.${toString vlanId};
    net = dt.networks.${name};
    reverseZone = "${net.ip6Reverse}.${dt.ulaReverseBase}.ip6.arpa";
    servers = labServersOnNetwork name;
    serverPtrs = lib.concatMapStringsSep "\n" (s:
      "${dt.utils.hostReverseNibbles (dt.utils.intToHex (conventions.hostBaseOffset + s.n))} IN PTR ${s.name}.${net.zoneName}."
    ) servers;
  in {
    name = reverseZone;
    value = {
      ddns = true;
      data = ''
        $ORIGIN ${reverseZone}.
        $TTL 300
        @    IN SOA  ns1.${net.zoneName}. admin.${net.zoneName}. (
                     1 3600 900 604800 300 )
        @    IN NS   ns1.${net.zoneName}.
        ${dt.utils.hostReverseNibbles (dt.utils.intToHex conventions.gatewayOffset)} IN PTR iyr.${net.zoneName}.
        ${serverPtrs}
      '';
    };
  };

  # Parent zone for home.psyclyx.net (transparent in unbound so DHCP names resolve)
  homeZone = {
    name = topo.domains.home;
    value = {
      ddns = false;
      data = ''
        $ORIGIN ${topo.domains.home}.
        $TTL 300
        @    IN SOA  ns1.${topo.domains.home}. admin.${topo.domains.home}. (
                     1 3600 900 604800 300 )
        @    IN NS   ns1.${topo.domains.home}.
        ns1  IN A    10.0.10.1
      '';
    };
  };

  authoritativeZones = builtins.listToAttrs (
    [homeZone]
    ++ (map mkForwardZoneData dt.dhcpVlans)
    ++ (map mkReverseZoneData dt.dhcpVlans)
    ++ (map mkIp6ReverseZoneData dt.dhcpVlans)
  );
in {
  config = lib.mkIf (config.psyclyx.nixos.host == "iyr") {
    psyclyx.nixos.network.dns.authoritative.zones = authoritativeZones;
    # tsigKeyFile/tsigKeyName and sops secrets are in modules/nixos/hosts/iyr.nix (private layer)

  };
}
