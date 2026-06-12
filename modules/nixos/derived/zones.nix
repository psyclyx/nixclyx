# Authoritative DNS zone generation from egregore entities.
#
# Generates forward, reverse (IPv4), and reverse (IPv6) zones for the
# networks gated by `gatewayHostname` (i.e. the networks this host is
# the gateway for), plus an optional site umbrella zone. Wires into
# psyclyx.nixos.network.dns.authoritative.zones.
{config, lib, ...}: let
  eg = config.psyclyx.egregore;

  cfg = config.psyclyx.nixos.network.dns;
  gwName = cfg.zones.gatewayHostname;

  # VLAN-keyed maps only cover networks with an actual VLAN ID, gated
  # to networks where gwName is the gateway. A host without that role
  # for a given network has no business being authoritative for it.
  networks = lib.filterAttrs (_: e: e.type == "network") eg.entities;
  # Networks this host serves DNS for. Prefer the explicit dnsRef
  # (refs.dns or site fallback) so an L2-only DHCP/DNS listener like
  # iyr serves storage/lab zones it isn't the gateway for; fall back
  # to gatewayRef when dnsRef isn't set so the existing
  # gateway-as-DNS case keeps working.
  vlanNetworks = lib.filterAttrs (
    _: e:
      e.network.vlan != null
      && (
        (e.attrs.dnsRef or null) == gwName
        || ((e.attrs.dnsRef or null) == null
            && (e.attrs.gatewayRef or null) == gwName)
      )
  ) networks;

  dhcpVlans = lib.sort builtins.lessThan
    (lib.mapAttrsToList (_: e: e.network.vlan) vlanNetworks);

  vlanNameMap = builtins.listToAttrs (lib.mapAttrsToList (name: e:
    lib.nameValuePair (toString e.network.vlan) name
  ) vlanNetworks);

  # Hosts with MAC + interface + declared address on a network.
  # Gateway-derived addresses don't count: the gateway gets its own
  # PTR via gwLastOctet/gwName below, so requiring a declared address
  # excludes the gateway from the PTR-server list it would otherwise
  # double up.
  managedHostsOnNetwork = network:
    lib.sort builtins.lessThan
      (builtins.attrNames (lib.filterAttrs (_: e:
        e.type == "host"
        && e.host.mac != {}
        && e.host.interfaces ? ${network}
        && e.host.addresses ? ${network}
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
    serverRecords = lib.concatMapStringsSep "\n" (hostname: let
      addr = eg.entities.${hostname}.host.addresses.${name};
      v4Line = "${hostname} IN A ${addr.ipv4}";
      v6Line = lib.optionalString
        ((addr.ipv6 or null) != null)
        "\n${hostname} IN AAAA ${addr.ipv6}";
    in v4Line + v6Line) servers;
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
        ${gwName}  IN A    ${net.gateway4}
        ${gwName}  IN AAAA ${net.gateway6}
        ${serverRecords}
        ${vipRecords}
        ${cfg.zones.extraRecords.${name} or ""}
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
        ${gwLastOctet} IN PTR ${gwName}.${net.zoneName}.
        ${serverPtrs}
      '';
    };
  };

  mkIp6ReverseZoneData = vlanId: let
    name = vlanNameMap.${toString vlanId};
    net = eg.entities.${name};
    na = net.attrs;
    reverseZone = "${na.ip6Reverse}.${ulaReverseBase}.ip6.arpa";
    # Only hosts with an IPv6 declared on this network — iyr's
    # storage entry is v4-only, for instance, so it's an A-record-
    # only listener.
    servers = lib.filter
      (h: (eg.entities.${h}.host.addresses.${name}.ipv6 or null) != null)
      (managedHostsOnNetwork name);
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
        ${gwReverseNibbles} IN PTR ${gwName}.${na.zoneName}.
        ${serverPtrs}
      '';
    };
  };

  # Site umbrella zone — the primary DNS namespace for hosts at a site.
  # Populated with static A records from a configured network + DDNS for dynamic clients.
  siteZoneCfg = cfg.zones.siteZone;
  siteZone = lib.optionalAttrs siteZoneCfg.enable (let
    me = eg.entities.${gwName} or null;
    mySiteName = if me != null then me.host.site or null else null;
    mySite = if mySiteName != null then eg.entities.${mySiteName} or null else null;
    siteDomain = if mySite != null then mySite.site.domain or null else null;

    # ns1 glue uses the first network's gateway. Picking from the
    # configured preference order keeps the choice predictable when
    # the site spans multiple gateway'd networks.
    ns1Net = eg.entities.${lib.head siteZoneCfg.networks};
    ns1Addr = ns1Net.attrs.gateway4;

    # All hosts at this site — we'll filter to those with a resolvable
    # address (incl. gateway-derived) on one of the listed networks.
    siteHosts = lib.filterAttrs (_: e:
      e.type == "host" && (e.host.site or null) == mySiteName
    ) eg.entities;

    # Pick the first network in the preference list for which this host
    # has a non-null IPv4 in its resolved addresses (host.attrs.addresses
    # already folds in gateway-derived entries).
    pickAddr = h: let
      candidates = h.attrs.addresses or {};
      hit = lib.findFirst
        (n: candidates ? ${n} && (candidates.${n}.ipv4 or null) != null)
        null
        siteZoneCfg.networks;
    in if hit == null then null else candidates.${hit};

    hostRecords = lib.concatStringsSep "\n" (lib.filter (s: s != "") (map (hostname: let
      addrs = pickAddr eg.entities.${hostname};
      v4 = lib.optionalString (addrs != null) "${hostname} IN A ${addrs.ipv4}";
      v6 = lib.optionalString (addrs != null && (addrs.ipv6 or null) != null)
        "\n${hostname} IN AAAA ${addrs.ipv6}";
    in v4 + v6)
    (lib.sort builtins.lessThan (builtins.attrNames siteHosts))));
  in lib.optionalAttrs (siteDomain != null && siteZoneCfg.networks != []) {
    ${siteDomain} = {
      # Static-only: no DDNS into the site apex. DHCP clients
      # register under their per-VLAN zone (see topology/dhcp.nix).
      ddns = false;
      data = ''
        $ORIGIN ${siteDomain}.
        $TTL 300
        @    IN SOA  ns1.${siteDomain}. admin.${siteDomain}. (
                     1 3600 900 604800 300 )
        @    IN NS   ns1.${siteDomain}.
        ns1  IN A    ${ns1Addr}
        ${hostRecords}
      '';
    };
  });

  generatedZones = builtins.listToAttrs (
    (map mkForwardZoneData dhcpVlans)
    ++ (map mkReverseZoneData dhcpVlans)
    ++ (map mkIp6ReverseZoneData dhcpVlans)
  ) // siteZone;
in {
  options.psyclyx.nixos.network.dns.zones = {
    enable = lib.mkEnableOption "auto-generate authoritative zones from egregore";
    gatewayHostname = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      defaultText = lib.literalExpression "config.networking.hostName";
      description = ''
        Hostname of the gateway/DNS server (for NS/A glue records and
        for filtering egregore networks by `refs.gateway`). Defaults
        to the running host's hostname — override only when serving
        zones on behalf of another egregore entity.
      '';
    };
    extraRecords = lib.mkOption {
      type = lib.types.attrsOf lib.types.lines;
      default = {};
      description = "Extra records appended to generated forward zones, keyed by egregore network name.";
      example = { stage = "app IN CNAME lab-stage-vip"; };
    };
    extraZones = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Additional zones merged with generated ones.";
    };
    siteZone = {
      enable = lib.mkEnableOption "site umbrella zone with host A records";
      networks = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = ''
          Ordered preference list of network entities. For each host at
          the site, the first network in this list for which the host
          has a non-null IPv4 (including gateway-derived addresses) is
          used to seed its site-apex A/AAAA record.
        '';
      };
    };
  };

  config = lib.mkIf cfg.zones.enable {
    psyclyx.nixos.network.dns.authoritative.zones = generatedZones // cfg.zones.extraZones;
  };
}
