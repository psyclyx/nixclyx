# Egregore → dhcp-ddns domain projection.
#
# For each active DHCP pool, derives the forward + reverse DDNS domain
# entries from the pool's network entity (zoneName, prefix, ip6Reverse)
# and feeds them to the generic dhcp-ddns module.
{config, lib, ...}: let
  cfg = config.psyclyx.nixos.network.dhcp-ddns;
  eg = config.psyclyx.egregore;
  dhcpCfg = config.psyclyx.nixos.services.dhcp;
  dnsCfg = config.psyclyx.nixos.network.dns;

  # Nibble-reverse the ULA prefix for IPv6 PTR zones.
  ulaReverseBase = let
    stripped = lib.replaceStrings [":"] [""] (eg.ipv6UlaPrefix or "");
  in lib.concatStringsSep "." (lib.reverseList (lib.stringToCharacters stripped));

  netAttrs = network: lib.attrByPath ["entities" network "attrs"] {} eg;

  mkDnsServer = {
    ip-address = "127.0.0.1";
    port = dnsCfg.authoritative.port;
  };

  mkForward = _: pool: let na = netAttrs pool.network; in {
    name = "${na.zoneName or ""}.";
    key-name = cfg.keyName;
    dns-servers = [mkDnsServer];
  };

  mkReverse4 = _: pool: let
    na = netAttrs pool.network;
    octets = lib.splitString "." (na.prefix or "0.0.0");
    reverseZone = "${lib.concatStringsSep "." (lib.reverseList octets)}.in-addr.arpa";
  in {
    name = "${reverseZone}.";
    key-name = cfg.keyName;
    dns-servers = [mkDnsServer];
  };

  mkReverse6 = _: pool: let
    na = netAttrs pool.network;
    reverseZone = "${na.ip6Reverse or ""}.${ulaReverseBase}.ip6.arpa";
  in {
    name = "${reverseZone}.";
    key-name = cfg.keyName;
    dns-servers = [mkDnsServer];
  };

  forwardDomains  = lib.mapAttrsToList mkForward  dhcpCfg.pools;
  reverseDomains4 = lib.mapAttrsToList mkReverse4 dhcpCfg.pools;
  reverseDomains6 = lib.mapAttrsToList mkReverse6 dhcpCfg.pools;
in {
  config = lib.mkIf (dhcpCfg.enable && dhcpCfg.pools != {}) {
    psyclyx.nixos.network.dhcp-ddns = {
      forwardDdnsDomains = forwardDomains;
      reverseDdnsDomains = reverseDomains4 ++ reverseDomains6;
    };
  };
}
