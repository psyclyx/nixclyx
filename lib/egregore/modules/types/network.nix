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

    # Resolve this network's refs against site-level fallback, in one
    # place, so `attrs` and `relations` can't disagree about the edge.
    resolve = entity: egregore: let
      net = entity.network;
      siteEntity = if net.site != null then egregore.entities.${net.site} or null else null;
      netRefs = entity.refs or {};
      siteRefs = if siteEntity != null then siteEntity.refs or {} else {};
    in {
      inherit siteEntity;
      siteDomain = if siteEntity != null then siteEntity.site.domain or null else null;
      dnsRef = netRefs.dns or siteRefs.dns or null;
      gatewayRef = netRefs.gateway or siteRefs.gateway or null;
      # Which router serves each family. Normally the same box, so v6
      # falls back to the v4 answer — but they are separate facts, and a
      # dual-stack network can legitimately have different routers for
      # each, which is what a migration looks like while it is halfway
      # done. Whoever is the v6 router holds the ULA gateway address,
      # sends the RAs and is advertised as the resolver in them; the v4
      # router holds the v4 gateway address. Fusing the two means moving
      # one silently moves the other.
      gateway6Ref = netRefs.gateway6 or netRefs.gateway
        or siteRefs.gateway6 or siteRefs.gateway or null;
    };
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
      dhcpRelay = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Relay DHCP for this segment instead of relying on the client's
          broadcast reaching the server by flooding. Every L3 device
          holding an address here emits a relay entry pointing at the
          network's DHCP server (refs.dns, with site fallback).

          Two cases need it: the server has no L2 presence on the segment
          (it's reached over a routed path), or the broadcast domain
          doesn't reliably carry the flood. Relay is purely additive — it
          adds a unicast path without suppressing the broadcast one — so
          enabling it where flooding already works is safe, and is the
          way to migrate off an L2-anchor without a flag day.
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

    # The edges this network has, resolved. `refs` is what the config
    # declared; these are what it means after site-level fallback. Core
    # inverts them into refsIn, so a router can ask "which networks
    # do I gateway?" — including ones that inherited it — instead of
    # every consumer re-deriving the fallback.
    relations = _name: entity: egregore: let r = resolve entity egregore; in {
      gateway = r.gatewayRef;
      gateway6 = r.gateway6Ref;
      dns = r.dnsRef;
    };

    deriveOptions = {
      vlan = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "802.1Q VLAN ID of this segment (mirrors `network.vlan`). Null for non-VLAN segments.";
      };
      prefix = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "First three octets of the IPv4 CIDR (e.g. \"10.0.25\").";
      };
      prefixLen = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "IPv4 prefix length of the CIDR.";
      };
      gateway4 = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "IPv4 gateway address of this segment.";
      };
      network4 = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "IPv4 network address of this segment.";
      };
      subnet6 = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "IPv6 ULA subnet CIDR. Empty when the fleet has no ULA prefix or the network has no ULA hex.";
      };
      gateway6 = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "IPv6 ULA gateway address. Empty when there is no ULA subnet.";
      };
      zoneName = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          DNS zone of this network (`<network>.<base domain>` — the site
          domain, or domains.internal for site-less overlays). Empty for
          a network with neither.
        '';
      };
      label = lib.mkOption { type = lib.types.str; };
      zone = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Policy zone this network belongs to (mirrors `network.zone`).";
      };
      dnsRef = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "DNS-server entity for this network, with site fallback applied.";
      };
      gatewayRef = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "v4 gateway (router) entity for this network, with site fallback applied.";
      };
      gateway6Ref = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "v6 gateway (router) entity for this network, with site fallback applied.";
      };
      ip6Reverse = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Nibble-reversed ULA hex for IPv6 PTR reverse zones. Empty when there is no ULA hex.";
      };
    };

    derive = name: entity: egregore: let
      net = entity.network;
      prefix = prefixOf net.ipv4;
      gw = egregore.conventions.gatewayOffset or 1;
      ulaPrefix = egregore.ipv6UlaPrefix or "";
      hasV6 = ulaPrefix != "" && net.ulaSubnetHex != "";
      r = resolve entity egregore;
      inherit (r) siteEntity siteDomain dnsRef gatewayRef gateway6Ref;

      # Zone name: site domain for site networks; for site-less overlays
      # (e.g. wireguard) fall back to domains.internal. A network with
      # neither is a config error and yields an empty zoneName.
      baseDomain =
        if siteDomain != null then siteDomain
        else egregore.domains.internal or "";
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
      inherit (net) zone;
      inherit dnsRef gatewayRef gateway6Ref;
      # DNS PTR reverse zone components.
      ip6Reverse = lib.optionalString (net.ulaSubnetHex != "")
        (reverseNibbles 4 net.ulaSubnetHex);
    };
  };
}
