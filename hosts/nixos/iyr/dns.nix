{config, lib, ...}: let
  eg = config.psyclyx.egregore;

  networks = lib.filterAttrs (_: e: e.type == "network") eg.entities;
  hosts = lib.filterAttrs (_: e: e.type == "host") eg.entities;

  # Sorted VLAN IDs for all networks.
  dhcpVlans = lib.sort builtins.lessThan
    (lib.mapAttrsToList (_: e: e.network.vlan) networks);

  # VLAN ID → network entity name.
  vlanNameMap = builtins.listToAttrs (lib.mapAttrsToList (name: e:
    lib.nameValuePair (toString e.network.vlan) name
  ) networks);

  # Hosts with MAC + interface on a network.
  managedHostsOnNetwork = network:
    lib.sort builtins.lessThan
      (builtins.attrNames (lib.filterAttrs (_: e:
        e.type == "host" && e.host.mac != {} && e.host.interfaces ? ${network}
      ) eg.entities));

  # Nibble-reverse for IPv6 PTR.
  reverseNibbles = width: hex: let
    padded = lib.fixedWidthString width "0" hex;
  in lib.concatStringsSep "." (lib.reverseList (lib.stringToCharacters padded));

  ulaReverseBase = let
    stripped = lib.replaceStrings [":"] [""] eg.ipv6UlaPrefix;
  in lib.concatStringsSep "." (lib.reverseList (lib.stringToCharacters stripped));

  # HA groups on a given network → VIP A records.
  vipRecordsForNetwork = networkName: let
    groups = lib.filterAttrs (_: e:
      e.type == "ha-group" && e.ha-group.network == networkName
    ) eg.entities;
  in
    lib.concatStringsSep "\n" (lib.mapAttrsToList (groupName: g:
      "${groupName}-vip IN A ${g.ha-group.vip.ipv4}"
    ) groups);

  mkForwardZoneData = vlanId: let
    name = vlanNameMap.${toString vlanId};
    net = eg.entities.${name}.attrs;
    servers = managedHostsOnNetwork name;
    serverRecords = lib.concatMapStringsSep "\n" (hostname:
      "${hostname} IN A ${eg.entities.${hostname}.host.addresses.${name}.ipv4}\n" +
      "${hostname} IN AAAA ${eg.entities.${hostname}.host.addresses.${name}.ipv6}"
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
        ${lib.optionalString (name == "stage") "angelbeats IN CNAME lab-1"}
      '';
    };
  };

  mkReverseZoneData = vlanId: let
    name = vlanNameMap.${toString vlanId};
    net = eg.entities.${name}.attrs;
    octets = lib.splitString "." net.prefix;
    reverseZone = "${lib.concatStringsSep "." (lib.reverseList octets)}.in-addr.arpa";
    servers = managedHostsOnNetwork name;
    serverPtrs = lib.concatMapStringsSep "\n" (hostname: let
      addr = eg.entities.${hostname}.host.addresses.${name}.ipv4;
      parts = lib.splitString "." addr;
      lastOctet = builtins.elemAt parts 3;
    in "${lastOctet} IN PTR ${hostname}.${net.zoneName}."
    ) servers;
    gwParts = lib.splitString "." net.gateway4;
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

  mkIp6ReverseZoneData = vlanId: let
    name = vlanNameMap.${toString vlanId};
    net = eg.entities.${name};
    na = net.attrs;
    reverseZone = "${na.ip6Reverse}.${ulaReverseBase}.ip6.arpa";
    servers = managedHostsOnNetwork name;
    hostPartReverseNibbles = addr: let
      parts = lib.splitString "::" addr;
      hostHex = builtins.elemAt parts 1;
    in reverseNibbles 16 hostHex;
    serverPtrs = lib.concatMapStringsSep "\n" (hostname:
      "${hostPartReverseNibbles eg.entities.${hostname}.host.addresses.${name}.ipv6} IN PTR ${hostname}.${na.zoneName}."
    ) servers;
    gwReverseNibbles = hostPartReverseNibbles na.gateway6;
  in {
    name = reverseZone;
    value = {
      ddns = true;
      data = ''
        $ORIGIN ${reverseZone}.
        $TTL 300
        @    IN SOA  ns1.${na.zoneName}. admin.${na.zoneName}. (
                     1 3600 900 604800 300 )
        @    IN NS   ns1.${na.zoneName}.
        ${gwReverseNibbles} IN PTR iyr.${na.zoneName}.
        ${serverPtrs}
      '';
    };
  };

  homeZone = {
    name = eg.domains.home;
    value = {
      ddns = false;
      data = ''
        $ORIGIN ${eg.domains.home}.
        $TTL 300
        @    IN SOA  ns1.${eg.domains.home}. admin.${eg.domains.home}. (
                     1 3600 900 604800 300 )
        @    IN NS   ns1.${eg.domains.home}.
        ns1  IN A    10.0.10.1
      '';
    };
  };

  authoritativeZones = builtins.listToAttrs (
    [homeZone]
    ++ (map mkForwardZoneData dhcpVlans)
    ++ (map mkReverseZoneData dhcpVlans)
    ++ (map mkIp6ReverseZoneData dhcpVlans)
  );
in {
  psyclyx.nixos.network.dns.authoritative.zones = authoritativeZones;
}
