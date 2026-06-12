# Entity type: network segment (VLAN-backed subnet).
{
  egregoreType = { lib, ... }: let
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
  in {
    name = "network";
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
      mtu = lib.mkOption {
        type = lib.types.int;
        default = 1500;
        description = "Link MTU for this segment. Hosts/switches inherit when projecting interfaces.";
      };
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
      zone = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          Policy zone this network belongs to (matches a zone entity's
          name). Gateway projections read `globals.policy.<src>.<dst>`
          keyed by zone, not network — multiple networks can share
          policy by joining the same zone. Empty = no zone assignment;
          forwards to/from this network must be enumerated explicitly
          by something else (or are implicit-drop).
        '';
      };
    };

    attrs = name: entity: top: let
      net = entity.network;
      prefix = prefixOf net.ipv4;
      gw = top.conventions.gatewayOffset or 1;
      ulaPrefix = top.ipv6UlaPrefix or "";
      hasV6 = ulaPrefix != "" && net.ulaSubnetHex != "";

      # Zone name: site domain for site networks; for site-less overlays
      # (e.g. wireguard) fall back to domains.internal. A network with
      # neither is a config error and yields an empty zoneName.
      siteEntity = if net.site != null then top.entities.${net.site} or null else null;
      siteDomain = if siteEntity != null then siteEntity.site.domain or null else null;
      baseDomain =
        if siteDomain != null then siteDomain
        else top.domains.internal or "";

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
      zone = net.zone;
      inherit dnsRef gatewayRef;
      # DNS PTR reverse zone components.
      ip6Reverse = lib.optionalString (net.ulaSubnetHex != "")
        (reverseNibbles 4 net.ulaSubnetHex);
    };
  };
}
