# Authoritative DNS zone generation from egregore entities.
#
# Generates forward, reverse (IPv4), and reverse (IPv6) zones for all
# network entities, plus a home umbrella zone.  Wires into
# psyclyx.nixos.network.dns.authoritative.zones.
{config, lib, ...}: let
  eg = config.psyclyx.egregore;

  networks = lib.filterAttrs (_: e: e.type == "network") eg.entities;

  dhcpVlans = lib.sort builtins.lessThan
    (lib.mapAttrsToList (_: e: e.network.vlan) networks);

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

  cfg = config.psyclyx.nixos.network.dns;
  gwName = cfg.zones.gatewayHostname;
  gwEntity = eg.entities.${gwName} or null;

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
    net = eg.entities.${siteZoneCfg.network};
    na = net.attrs;

    # All hosts at this site with an address on the configured network.
    siteHosts = lib.filterAttrs (_: e:
      e.type == "host" && e.host.site == mySiteName
      && e.host.addresses ? ${siteZoneCfg.network}
      && e.host.addresses.${siteZoneCfg.network}.ipv4 != null
    ) eg.entities;

    hostRecords = lib.concatMapStringsSep "\n" (hostname: let
      addr = eg.entities.${hostname}.host.addresses.${siteZoneCfg.network}.ipv4;
    in "${hostname} IN A ${addr}")
    (lib.sort builtins.lessThan (builtins.attrNames siteHosts));
  in lib.optionalAttrs (siteDomain != null) {
    ${siteDomain} = {
      ddns = true;
      data = ''
        $ORIGIN ${siteDomain}.
        $TTL 300
        @    IN SOA  ns1.${siteDomain}. admin.${siteDomain}. (
                     1 3600 900 604800 300 )
        @    IN NS   ns1.${siteDomain}.
        ns1  IN A    ${na.gateway4}
        ${gwName}  IN A    ${na.gateway4}
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
      description = "Hostname of the gateway/DNS server (for NS/A glue records).";
    };
    extraRecords = lib.mkOption {
      type = lib.types.attrsOf lib.types.lines;
      default = {};
      description = "Extra records appended to generated forward zones, keyed by egregore network name.";
      example = { stage = "angelbeats IN CNAME lab-stage-vip"; };
    };
    extraZones = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Additional zones merged with generated ones.";
    };
    siteZone = {
      enable = lib.mkEnableOption "site umbrella zone with host A records";
      network = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Network entity whose addresses populate the site zone.";
      };
    };
  };

  config = lib.mkIf cfg.zones.enable {
    psyclyx.nixos.network.dns.authoritative.zones = generatedZones // cfg.zones.extraZones;
  };
}
