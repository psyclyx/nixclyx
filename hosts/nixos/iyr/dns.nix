{
  config,
  lib,
  ...
}: let
  topo = config.psyclyx.topology;
  fleet = config.psyclyx.fleet;

  # Derive VIP A records for haGroups on a given network.
  vipRecordsForNetwork = networkName: let
    groups = lib.filterAttrs (_: g: g.network == networkName) topo.haGroups;
  in
    lib.concatStringsSep "\n" (lib.mapAttrsToList (groupName: _group:
      "${groupName}-vip IN A ${fleet.groupVip groupName}"
    ) groups);

  # Build a forward zone file for a VLAN's network.
  mkForwardZoneData = vlanId: let
    name = fleet.enriched.vlanNameMap.${toString vlanId};
    net = fleet.networks.${name};
    servers = fleet.managedHostsOnNetwork name;
    serverRecords = lib.concatMapStringsSep "\n" (hostname:
      "${hostname} IN A ${fleet.hostAddress hostname name}\n" +
      "${hostname} IN AAAA ${fleet.hostAddress6 hostname name}"
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
    name = fleet.enriched.vlanNameMap.${toString vlanId};
    net = fleet.networks.${name};
    octets = lib.splitString "." net.prefix;
    reverseZone = "${lib.concatStringsSep "." (lib.reverseList octets)}.in-addr.arpa";
    servers = fleet.managedHostsOnNetwork name;
    serverPtrs = lib.concatMapStringsSep "\n" (hostname: let
      addr = fleet.hostAddress hostname name;
      parts = lib.splitString "." addr;
      lastOctet = builtins.elemAt parts 3;
    in
      "${lastOctet} IN PTR ${hostname}.${net.zoneName}."
    ) servers;
    gwAddr = net.gateway4;
    gwParts = lib.splitString "." gwAddr;
    gwLastOctet = builtins.elemAt gwParts 3;
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
        ${gwLastOctet} IN PTR iyr.${net.zoneName}.
        ${serverPtrs}
      '';
    };
  };

  # Build a reverse (PTR) zone file for a VLAN's IPv6 ULA network.
  mkIp6ReverseZoneData = vlanId: let
    name = fleet.enriched.vlanNameMap.${toString vlanId};
    net = fleet.networks.${name};
    reverseZone = "${net.ip6Reverse}.${fleet.enriched.ulaReverseBase}.ip6.arpa";
    servers = fleet.managedHostsOnNetwork name;
    hostPartReverseNibbles = addr: let
      parts = lib.splitString "::" addr;
      hostHex = builtins.elemAt parts 1;
    in fleet.utils.hostReverseNibbles hostHex;
    serverPtrs = lib.concatMapStringsSep "\n" (hostname:
      "${hostPartReverseNibbles (fleet.hostAddress6 hostname name)} IN PTR ${hostname}.${net.zoneName}."
    ) servers;
    gwReverseNibbles = hostPartReverseNibbles net.gateway6;
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
        ${gwReverseNibbles} IN PTR iyr.${net.zoneName}.
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
    ++ (map mkForwardZoneData fleet.enriched.dhcpVlans)
    ++ (map mkReverseZoneData fleet.enriched.dhcpVlans)
    ++ (map mkIp6ReverseZoneData fleet.enriched.dhcpVlans)
  );
in {
  psyclyx.nixos.network.dns.authoritative.zones = authoritativeZones;
}
