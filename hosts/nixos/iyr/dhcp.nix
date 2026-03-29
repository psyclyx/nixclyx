{config, lib, pkgs, ...}: let
  eg = config.psyclyx.egregore;

  networks = lib.filterAttrs (_: e: e.type == "network") eg.entities;

  # Nibble-reverse for DNS PTR.
  reverseNibbles = width: hex: let
    padded = lib.fixedWidthString width "0" hex;
  in lib.concatStringsSep "." (lib.reverseList (lib.stringToCharacters padded));

  ulaReverseBase = let
    stripped = lib.replaceStrings [":"] [""] eg.ipv6UlaPrefix;
  in lib.concatStringsSep "." (lib.reverseList (lib.stringToCharacters stripped));

  cfg = config.psyclyx.nixos.services.dhcp;

  mkForwardDdnsDomain = _poolName: pool: let
    na = eg.entities.${pool.network}.attrs;
  in {
    name = "${na.zoneName}.";
    key-name = "ddns-iyr";
    dns-servers = [{
      ip-address = "127.0.0.1";
      port = config.psyclyx.nixos.network.dns.authoritative.port;
    }];
  };

  mkReverseDdnsDomain4 = _poolName: pool: let
    na = eg.entities.${pool.network}.attrs;
    octets = lib.splitString "." na.prefix;
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
    net = eg.entities.${pool.network};
    reverseZone = "${net.attrs.ip6Reverse}.${ulaReverseBase}.ip6.arpa";
  in {
    name = "${reverseZone}.";
    key-name = "ddns-iyr";
    dns-servers = [{
      ip-address = "127.0.0.1";
      port = config.psyclyx.nixos.network.dns.authoritative.port;
    }];
  };

  forwardDdnsDomains = lib.mapAttrsToList mkForwardDdnsDomain cfg.pools;
  reverseDdnsDomains4 = lib.mapAttrsToList mkReverseDdnsDomain4 cfg.pools;
  reverseDdnsDomains6 = lib.mapAttrsToList mkReverseDdnsDomain6 cfg.pools;
in {
  psyclyx.nixos.services.dhcp = {
    enable = true;
    interface = "enp1s0";
    pools = {
      main  = { network = "main";  ipv4Range = { start = "10.0.10.100";  end = "10.0.10.199"; }; };
      infra = { network = "infra"; ipv4Range = { start = "10.0.25.100";  end = "10.0.25.199"; }; };
      prod  = { network = "prod";  ipv4Range = { start = "10.0.30.100";  end = "10.0.30.199"; }; };
      stage = { network = "stage"; ipv4Range = { start = "10.0.31.100";  end = "10.0.31.199"; }; };
      data  = { network = "data";  ipv4Range = { start = "10.0.50.100";  end = "10.0.50.199"; }; };
      guest = { network = "guest"; ipv4Range = { start = "10.0.100.10";  end = "10.0.100.249"; }; };
      iot   = { network = "iot";   ipv4Range = { start = "10.0.110.10";  end = "10.0.110.249"; }; };
      mgmt  = {
        network = "mgmt";
        ipv4Range = { start = "10.0.240.100"; end = "10.0.240.199"; };
        extraReservations = [
          { "hw-address" = "04:F4:1C:54:1D:8A"; "ip-address" = "10.0.240.2"; hostname = "mdf-agg01"; }
          { "hw-address" = "2C:C8:1B:00:82:89"; "ip-address" = "10.0.240.3"; hostname = "mdf-acc01"; }
        ];
      };
    };
    extraDhcp4 = {
      dhcp-ddns.enable-updates = true;
      ddns-override-client-update = true;
      ddns-override-no-update = true;
      ddns-replace-client-name = "when-not-present";
      ddns-conflict-resolution-mode = "no-check-with-dhcid";
    };
    extraDhcp6 = {
      dhcp-ddns.enable-updates = true;
      ddns-override-client-update = true;
      ddns-override-no-update = true;
      ddns-replace-client-name = "when-not-present";
      ddns-conflict-resolution-mode = "no-check-with-dhcid";
      loggers = [{
        name = "kea-dhcp6";
        output_options = [{output = "stdout";}];
        severity = "WARN";
      }];
    };
  };

  services.kea.dhcp-ddns = {
    enable = true;
    settings = {
      ip-address = "127.0.0.1";
      port = 53001;
      forward-ddns.ddns-domains = forwardDdnsDomains;
      reverse-ddns.ddns-domains = reverseDdnsDomains4 ++ reverseDdnsDomains6;
    };
  };

  systemd.services.kea-dhcp4-server.after = ["knot.service" "kea-dhcp-ddns-server.service"];
  systemd.services.kea-dhcp6-server.after = ["knot.service" "kea-dhcp-ddns-server.service"];
}
