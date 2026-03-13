{
  config,
  lib,
  ...
}: let
  topo = config.psyclyx.topology;
  dt = topo.enriched;
  conventions = topo.conventions;

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
      '';
    };
  };

  # Build a reverse (PTR) zone file for a VLAN's IPv6 ULA network.
  mkIp6ReverseZoneData = vlanId: let
    name = dt.vlanNameMap.${toString vlanId};
    net = dt.networks.${name};
    reverseZone = "${net.ip6Reverse}.${dt.ulaReverseBase}.ip6.arpa";
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
