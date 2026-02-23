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

  mkForwardZone = vlanId: let
    name = dt.vlanNameMap.${toString vlanId};
    net = dt.networks.${name};
    prefix6 = "${topo.ipv6UlaPrefix}:${net.vlanHex}";
    gatewayRecord = "iyr.${net.zoneName}. IN A ${net.gateway4}";
    gatewayRecord6 = "iyr.${net.zoneName}. IN AAAA ${net.gateway6}";
    servers = labServersOnNetwork name;
    serverRecords =
      map (s: "${s.name}.${net.zoneName}. IN A ${net.prefix}.${toString (conventions.hostBaseOffset + s.n)}")
      servers;
    serverRecords6 =
      map (s: "${s.name}.${net.zoneName}. IN AAAA ${prefix6}::${dt.utils.intToHex (conventions.hostBaseOffset + s.n)}")
      servers;
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
    servers = labServersOnNetwork name;
    serverPtrs =
      map (s: "${toString (conventions.hostBaseOffset + s.n)}.${reverseZone}. IN PTR ${s.name}.${net.zoneName}.")
      servers;
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
    servers = labServersOnNetwork name;
    serverPtrs =
      map (s: "${dt.utils.hostReverseNibbles (dt.utils.intToHex (conventions.hostBaseOffset + s.n))}.${reverseZone}. IN PTR ${s.name}.${net.zoneName}.")
      servers;
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
