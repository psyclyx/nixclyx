# Entity type: network segment (VLAN-backed subnet).
{ lib, egregorLib, config, ... }:
let
  parseCidr = cidr: let
    parts = lib.splitString "/" cidr;
  in {
    addr = builtins.head parts;
    prefixLen = lib.toInt (builtins.elemAt parts 1);
  };

  prefixOf = cidr: let
    octets = lib.splitString "." (parseCidr cidr).addr;
  in "${builtins.elemAt octets 0}.${builtins.elemAt octets 1}.${builtins.elemAt octets 2}";

  # Nibble-reverse a hex string for DNS PTR records.
  reverseNibbles = width: hex: let
    padded = lib.fixedWidthString width "0" hex;
    chars = lib.stringToCharacters padded;
  in lib.concatStringsSep "." (lib.reverseList chars);
in
egregorLib.mkType {
  name = "network";
  topConfig = config;
  description = "VLAN-backed network segment.";

  options = {
    vlan = lib.mkOption { type = lib.types.int; default = 0; description = "802.1Q VLAN ID."; };
    ipv4 = lib.mkOption { type = lib.types.str; default = ""; description = "IPv4 CIDR (e.g. 10.0.25.0/24)."; };
    ulaSubnetHex = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "ULA subnet hex suffix for IPv6 derivation.";
    };
    ipv6PdSubnetId = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
    };
    site = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Site entity name this network belongs to.";
    };
  };

  attrs = name: entity: top: let
    net = entity.network;
    prefix = prefixOf net.ipv4;
    gw = top.conventions.gatewayOffset or 1;
    ulaPrefix = top.ipv6UlaPrefix or "";
    hasV6 = ulaPrefix != "" && net.ulaSubnetHex != "";

    # Zone name: use site domain if available, fall back to domains.home.
    siteEntity = if net.site != null then top.entities.${net.site} or null else null;
    siteDomain = if siteEntity != null then siteEntity.site.domain or null else null;
    baseDomain = if siteDomain != null then siteDomain
                 else top.domains.home or "";
  in {
    vlan = net.vlan;
    prefix = prefix;
    prefixLen = (parseCidr net.ipv4).prefixLen;
    gateway4 = "${prefix}.${toString gw}";
    network4 = "${prefix}.0";
    subnet6 = lib.optionalString hasV6 "${ulaPrefix}:${net.ulaSubnetHex}::/64";
    gateway6 = lib.optionalString hasV6 "${ulaPrefix}:${net.ulaSubnetHex}::${lib.toHexString gw}";
    zoneName = lib.optionalString (baseDomain != "") "${name}.${baseDomain}";
    label = "VLAN ${toString net.vlan} (${net.ipv4})";
    site = net.site;
    # DNS PTR reverse zone components.
    ip6Reverse = lib.optionalString (net.ulaSubnetHex != "")
      (reverseNibbles 4 net.ulaSubnetHex);
  };
}
