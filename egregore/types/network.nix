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
in
egregorLib.mkType {
  name = "network";
  topConfig = config;
  description = "VLAN-backed network segment.";

  options = {
    vlan = lib.mkOption { type = lib.types.int; description = "802.1Q VLAN ID."; };
    ipv4 = lib.mkOption { type = lib.types.str; description = "IPv4 CIDR (e.g. 10.0.25.0/24)."; };
    ulaSubnetHex = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "ULA subnet hex suffix for IPv6 derivation.";
    };
    ipv6PdSubnetId = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
    };
  };

  attrs = name: entity: top: let
    net = entity.network;
    prefix = prefixOf net.ipv4;
    gw = top.conventions.gatewayOffset or 1;
    ulaPrefix = top.ipv6UlaPrefix or "";
    homeDomain = top.domains.home or "";
  in {
    vlan = net.vlan;
    prefix = prefix;
    prefixLen = (parseCidr net.ipv4).prefixLen;
    gateway4 = "${prefix}.${toString gw}";
    network4 = "${prefix}.0";
    subnet6 = lib.optionalString (ulaPrefix != "" && net.ulaSubnetHex != "")
      "${ulaPrefix}:${net.ulaSubnetHex}::/64";
    gateway6 = lib.optionalString (ulaPrefix != "" && net.ulaSubnetHex != "")
      "${ulaPrefix}:${net.ulaSubnetHex}::${lib.toHexString gw}";
    zoneName = lib.optionalString (homeDomain != "")
      "${name}.${homeDomain}";
    label = "VLAN ${toString net.vlan} (${net.ipv4})";
  };
}
