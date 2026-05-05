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
  description = "L3 IP segment, optionally VLAN-backed.";

  options = {
    vlan = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = ''
        802.1Q VLAN ID. Null for non-VLAN-backed networks (overlays,
        untagged segments). VLAN-aware projections (zones, dhcp,
        interface generation) skip null-vlan networks.
      '';
    };
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
    underlay = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Per-site underlay mapping for overlay networks. Each entry
        site → networkName declares: "within <site>, addresses on this
        overlay are also reachable via the host's address on
        <networkName>." A site router projection can then emit /32
        host routes for overlay-peer addresses via their underlay
        address, avoiding hairpin through the overlay's transport.

        Has no effect on non-overlay networks. Empty (default) means
        the overlay has no site-local shortcut anywhere.
      '';
    };
  };

  attrs = name: entity: top: let
    net = entity.network;
    prefix = prefixOf net.ipv4;
    gw = top.conventions.gatewayOffset or 1;
    ulaPrefix = top.ipv6UlaPrefix or "";
    hasV6 = ulaPrefix != "" && net.ulaSubnetHex != "";

    # Zone name: use site domain if available, fall back to domains.internal
    # for non-site networks (overlays), else domains.home.
    siteEntity = if net.site != null then top.entities.${net.site} or null else null;
    siteDomain = if siteEntity != null then siteEntity.site.domain or null else null;
    baseDomain = if siteDomain != null then siteDomain
                 else if net.site == null && (top.domains.internal or "") != ""
                      then top.domains.internal
                 else top.domains.home or "";

    # Refs with site-level fallback.
    netRefs = entity.refs or {};
    siteRefs = if siteEntity != null then siteEntity.refs or {} else {};
    dnsRef = netRefs.dns or siteRefs.dns or null;
    gatewayRef = netRefs.gateway or siteRefs.gateway or null;
  in {
    vlan = net.vlan;
    prefix = prefix;
    prefixLen = (parseCidr net.ipv4).prefixLen;
    gateway4 = "${prefix}.${toString gw}";
    network4 = "${prefix}.0";
    subnet6 = lib.optionalString hasV6 "${ulaPrefix}:${net.ulaSubnetHex}::/64";
    gateway6 = lib.optionalString hasV6 "${ulaPrefix}:${net.ulaSubnetHex}::${lib.toHexString gw}";
    zoneName = lib.optionalString (baseDomain != "") "${name}.${baseDomain}";
    label =
      if net.vlan != null
      then "VLAN ${toString net.vlan} (${net.ipv4})"
      else "(${net.ipv4})";
    site = net.site;
    inherit dnsRef gatewayRef;
    # DNS PTR reverse zone components.
    ip6Reverse = lib.optionalString (net.ulaSubnetHex != "")
      (reverseNibbles 4 net.ulaSubnetHex);
  };
}
