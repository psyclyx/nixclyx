{
  config,
  lib,
  pkgs,
  ...
}: let
  topo = config.psyclyx.topology;
  dt = topo.enriched;

  # Build DDNS domain entries for Kea D2 from the DHCP pools.
  mkForwardDdnsDomain = _poolName: pool: let
    net = dt.networks.${pool.network};
  in {
    name = "${net.zoneName}.";
    key-name = "ddns-iyr";
    dns-servers = [{
      ip-address = "127.0.0.1";
      port = config.psyclyx.nixos.network.dns.authoritative.port;
    }];
  };

  mkReverseDdnsDomain4 = _poolName: pool: let
    net = dt.networks.${pool.network};
    octets = lib.splitString "." net.prefix;
    reverseZone = "${lib.concatStringsSep "." (lib.reverseList octets)}.in-addr.arpa";
  in {
    name = "${reverseZone}.";
    key-name = "ddns-iyr";
    dns-servers = [{
      ip-address = "127.0.0.1";
      port = config.psyclyx.nixos.network.dns.authoritative.port;
    }];
  };

  mkReverseDdnsDomain6 = _poolName: pool: let
    net = dt.networks.${pool.network};
    reverseZone = "${net.ip6Reverse}.${dt.ulaReverseBase}.ip6.arpa";
  in {
    name = "${reverseZone}.";
    key-name = "ddns-iyr";
    dns-servers = [{
      ip-address = "127.0.0.1";
      port = config.psyclyx.nixos.network.dns.authoritative.port;
    }];
  };

  forwardDdnsDomains = lib.mapAttrsToList mkForwardDdnsDomain config.psyclyx.topology.dhcp.pools;
  reverseDdnsDomains4 = lib.mapAttrsToList mkReverseDdnsDomain4 config.psyclyx.topology.dhcp.pools;
  reverseDdnsDomains6 = lib.mapAttrsToList mkReverseDdnsDomain6 config.psyclyx.topology.dhcp.pools;
in {
  config = lib.mkIf (config.psyclyx.nixos.host == "iyr") {
    psyclyx.topology.dhcp = {
      enable = true;
      interface = "enp1s0";
      pools = {
        main = {
          network = "main";
          ipv4Range = { start = "10.0.10.100"; end = "10.0.10.199"; };
        };
        infra = {
          network = "infra";
          ipv4Range = { start = "10.0.25.100"; end = "10.0.25.199"; };
        };
        prod = {
          network = "prod";
          ipv4Range = { start = "10.0.30.100"; end = "10.0.30.199"; };
        };
        stage = {
          network = "stage";
          ipv4Range = { start = "10.0.31.100"; end = "10.0.31.199"; };
        };
        data = {
          network = "data";
          ipv4Range = { start = "10.0.50.100"; end = "10.0.50.199"; };
        };
        guest = {
          network = "guest";
          ipv4Range = { start = "10.0.100.10"; end = "10.0.100.249"; };
        };
        iot = {
          network = "iot";
          ipv4Range = { start = "10.0.110.10"; end = "10.0.110.249"; };
        };
        mgmt = {
          network = "mgmt";
          ipv4Range = { start = "10.0.240.100"; end = "10.0.240.199"; };
          extraReservations = [
            { "hw-address" = "04:F4:1C:54:1D:8A"; "ip-address" = "10.0.240.2"; hostname = "crs326"; }
            { "hw-address" = "2C:C8:1B:00:82:89"; "ip-address" = "10.0.240.3"; hostname = "css326"; }
          ];
        };
      };
      extraDhcp4 = {
        dhcp-ddns = {
          enable-updates = true;
        };
        ddns-override-client-update = true;
        ddns-override-no-update = true;
        ddns-replace-client-name = "when-not-present";
        ddns-conflict-resolution-mode = "no-check-with-dhcid";
      };
      extraDhcp6 = {
        dhcp-ddns = {
          enable-updates = true;
        };
        ddns-override-client-update = true;
        ddns-override-no-update = true;
        ddns-replace-client-name = "when-not-present";
        ddns-conflict-resolution-mode = "no-check-with-dhcid";
        # Suppress per-packet INFO noise (lab BMC interfaces solicit aggressively).
        loggers = [
          {
            name = "kea-dhcp6";
            output_options = [{output = "stdout";}];
            severity = "WARN";
          }
        ];
      };
    };

    # Kea D2 (DHCP-DDNS) sends RFC 2136 updates to Knot
    services.kea.dhcp-ddns = {
      enable = true;
      settings = {
        ip-address = "127.0.0.1";
        port = 53001;
        forward-ddns = {
          ddns-domains = forwardDdnsDomains;
        };
        reverse-ddns = {
          ddns-domains = reverseDdnsDomains4 ++ reverseDdnsDomains6;
        };
      };
    };

    # DHCP servers must start after Knot (zone data must be available for D2)
    systemd.services.kea-dhcp4-server.after = ["knot.service" "kea-dhcp-ddns-server.service"];
    systemd.services.kea-dhcp6-server.after = ["knot.service" "kea-dhcp-ddns-server.service"];
  };
}
