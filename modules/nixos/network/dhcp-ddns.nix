# DHCP Dynamic DNS (RFC 2136) via Kea DHCP-DDNS.
#
# Wires Kea dhcp-ddns to the authoritative DNS server, generating
# forward and reverse DDNS domain entries from the DHCP pool config.
{
  path = ["psyclyx" "nixos" "network" "dhcp-ddns"];
  description = "DHCP dynamic DNS updates via Kea DHCP-DDNS";
  options = { lib, ... }: {
    port = lib.mkOption {
      type = lib.types.port;
      default = 53001;
      description = "Port for the DHCP-DDNS service.";
    };
    keyName = lib.mkOption {
      type = lib.types.str;
      default = "ddns-iyr";
      description = "TSIG key name for DNS updates.";
    };
  };
  config = { cfg, config, lib, ... }: let
    eg = config.psyclyx.egregore;
    dhcpCfg = config.psyclyx.nixos.services.dhcp;
    dnsCfg = config.psyclyx.nixos.network.dns;

    networks = lib.filterAttrs (_: e: e.type == "network") eg.entities;

    # Nibble-reverse for IPv6 PTR.
    ulaReverseBase = let
      stripped = lib.replaceStrings [":"] [""] eg.ipv6UlaPrefix;
    in lib.concatStringsSep "." (lib.reverseList (lib.stringToCharacters stripped));

    mkDnsServer = {
      ip-address = "127.0.0.1";
      port = dnsCfg.authoritative.port;
    };

    mkForwardDdnsDomain = _poolName: pool: let
      na = eg.entities.${pool.network}.attrs;
    in {
      name = "${na.zoneName}.";
      key-name = cfg.keyName;
      dns-servers = [mkDnsServer];
    };

    mkReverseDdnsDomain4 = _poolName: pool: let
      na = eg.entities.${pool.network}.attrs;
      octets = lib.splitString "." na.prefix;
      reverseZone = "${lib.concatStringsSep "." (lib.reverseList octets)}.in-addr.arpa";
    in {
      name = "${reverseZone}.";
      key-name = cfg.keyName;
      dns-servers = [mkDnsServer];
    };

    mkReverseDdnsDomain6 = _poolName: pool: let
      net = eg.entities.${pool.network};
      reverseZone = "${net.attrs.ip6Reverse}.${ulaReverseBase}.ip6.arpa";
    in {
      name = "${reverseZone}.";
      key-name = cfg.keyName;
      dns-servers = [mkDnsServer];
    };

    forwardDdnsDomains = lib.mapAttrsToList mkForwardDdnsDomain dhcpCfg.pools;
    reverseDdnsDomains4 = lib.mapAttrsToList mkReverseDdnsDomain4 dhcpCfg.pools;
    reverseDdnsDomains6 = lib.mapAttrsToList mkReverseDdnsDomain6 dhcpCfg.pools;

    # Site zone DDNS domain — clients register as hostname.siteDomain.
    # Deduplicated: all pools at the same site share one site zone entry.
    siteZoneCfg = config.psyclyx.nixos.network.dns.zones.siteZone or { enable = false; };
    siteDdnsDomains = let
      hostName = config.networking.hostName;
      me = eg.entities.${hostName} or null;
      mySiteName = if me != null then me.host.site or null else null;
      mySite = if mySiteName != null then eg.entities.${mySiteName} or null else null;
      siteDomain = if mySite != null then mySite.site.domain or null else null;
    in lib.optional (siteZoneCfg.enable && siteDomain != null) {
      name = "${siteDomain}.";
      key-name = cfg.keyName;
      dns-servers = [mkDnsServer];
    };
  in lib.mkIf (dhcpCfg.enable && dhcpCfg.pools != {}) {
    services.kea.dhcp-ddns = {
      enable = true;
      settings = {
        ip-address = "127.0.0.1";
        inherit (cfg) port;
        forward-ddns.ddns-domains = siteDdnsDomains ++ forwardDdnsDomains;
        reverse-ddns.ddns-domains = reverseDdnsDomains4 ++ reverseDdnsDomains6;
      };
    };

    systemd.services.kea-dhcp4-server.after = ["knot.service" "kea-dhcp-ddns-server.service"];
    systemd.services.kea-dhcp6-server.after = ["knot.service" "kea-dhcp-ddns-server.service"];
  };
}
