# DHCP Dynamic DNS (RFC 2136) via Kea DHCP-DDNS.
#
# Generic shape: takes a port, a TSIG key name, and pre-resolved
# forward / reverse DDNS domain lists. A topology projection (see
# `topology/dhcp-ddns.nix`) reads egregore and the active DHCP pools
# to compute the domain lists per fleet network.
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
    dnsServerPort = lib.mkOption {
      type = lib.types.port;
      default = 53;
      description = ''
        Port of the authoritative DNS server (localhost). The projection
        typically wires this to `psyclyx.nixos.network.dns.authoritative.port`.
      '';
    };
    forwardDdnsDomains = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule { freeformType = lib.types.attrs; });
      default = [];
      description = ''
        Pre-resolved forward DDNS domain definitions (Kea's
        forward-ddns.ddns-domains shape: name, key-name, dns-servers).
      '';
    };
    reverseDdnsDomains = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule { freeformType = lib.types.attrs; });
      default = [];
      description = "Pre-resolved reverse DDNS domain definitions (v4 + v6).";
    };
  };
  config = { cfg, lib, ... }: lib.mkIf (cfg.forwardDdnsDomains != [] || cfg.reverseDdnsDomains != []) {
    services.kea.dhcp-ddns = {
      enable = true;
      settings = {
        ip-address = "127.0.0.1";
        inherit (cfg) port;
        # No site-zone DDNS forwarder: the site apex is static-only,
        # populated from egregore by topology/zones.nix:siteZone. Each
        # interface DDNS-registers under its per-VLAN zone via the
        # per-pool ddns-qualifying-suffix in topology/dhcp.nix.
        forward-ddns.ddns-domains = cfg.forwardDdnsDomains;
        reverse-ddns.ddns-domains = cfg.reverseDdnsDomains;
      };
    };

    systemd.services.kea-dhcp4-server.after = ["knot.service" "kea-dhcp-ddns-server.service"];
    systemd.services.kea-dhcp6-server.after = ["knot.service" "kea-dhcp-ddns-server.service"];
  };
}
