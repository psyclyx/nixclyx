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
    interfaces = host.mac;
  }) (lib.filterAttrs (_: host: host.labIndex != null) topo.hosts));

  mkForwardZone = vlanId: let
    name = dt.vlanNameMap.${toString vlanId};
    net = dt.networks.${name};
    prefix6 = "${topo.ipv6UlaPrefix}:${net.vlanHex}";
    gatewayRecord = "iyr.${net.zoneName}. IN A ${net.gateway4}";
    gatewayRecord6 = "iyr.${net.zoneName}. IN AAAA ${net.gateway6}";
    serverRecords =
      if net.labIface == null
      then []
      else
        map (s: "${s.name}.${net.zoneName}. IN A ${net.prefix}.${toString (conventions.hostBaseOffset + s.n)}")
        labServers;
    serverRecords6 =
      if net.labIface == null
      then []
      else
        map (s: "${s.name}.${net.zoneName}. IN AAAA ${prefix6}::${dt.utils.intToHex (conventions.hostBaseOffset + s.n)}")
        labServers;
  in {
    name = net.zoneName;
    value = {
      type = "static";
      records = [gatewayRecord gatewayRecord6] ++ serverRecords ++ serverRecords6;
    };
  };

  mkReverseZone = vlanId: let
    name = dt.vlanNameMap.${toString vlanId};
    net = dt.networks.${name};
    octets = lib.splitString "." net.prefix;
    reverseZone = "${lib.concatStringsSep "." (lib.reverseList octets)}.in-addr.arpa";
    gatewayPtr = "${toString conventions.gatewayOffset}.${reverseZone}. IN PTR iyr.${net.zoneName}.";
    serverPtrs =
      if net.labIface == null
      then []
      else
        map (s: "${toString (conventions.hostBaseOffset + s.n)}.${reverseZone}. IN PTR ${s.name}.${net.zoneName}.")
        labServers;
  in {
    name = reverseZone;
    value = {
      type = "static";
      records = [gatewayPtr] ++ serverPtrs;
    };
  };

  mkIp6ReverseZone = vlanId: let
    name = dt.vlanNameMap.${toString vlanId};
    net = dt.networks.${name};
    reverseZone = "${net.ip6Reverse}.${dt.ulaReverseBase}.ip6.arpa";
    gatewayPtr = "${dt.utils.hostReverseNibbles (dt.utils.intToHex conventions.gatewayOffset)}.${reverseZone}. IN PTR iyr.${net.zoneName}.";
    serverPtrs =
      if net.labIface == null
      then []
      else
        map (s: "${dt.utils.hostReverseNibbles (dt.utils.intToHex (conventions.hostBaseOffset + s.n))}.${reverseZone}. IN PTR ${s.name}.${net.zoneName}.")
        labServers;
  in {
    name = reverseZone;
    value = {
      type = "static";
      records = [gatewayPtr] ++ serverPtrs;
    };
  };

  localZones = builtins.listToAttrs (
    [
      {
        name = topo.domains.home;
        value = {
          type = "static";
          records = [];
        };
      }
    ]
    ++ (map mkForwardZone dt.dhcpVlans)
    ++ (map mkReverseZone dt.dhcpVlans)
    ++ (map mkIp6ReverseZone dt.dhcpVlans)
  );
in {
  config = lib.mkIf (config.psyclyx.nixos.host == "iyr") {
    psyclyx.nixos.network.dns.resolver.localZones = localZones;

    services.unbound.localControlSocketPath = "/run/unbound/unbound.ctl";
  };
}
