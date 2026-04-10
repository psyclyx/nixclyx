{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.nixos.hosts.semuta.network;
in {
  options.psyclyx.nixos.hosts.semuta.network = {
    ipv4 = lib.mkOption {
      type = lib.types.str;
      default = "192.0.2.1";
      description = "Public IPv4 address.";
    };
    ipv6Prefix = lib.mkOption {
      type = lib.types.str;
      default = "2001:db8::";
      description = "IPv6 prefix.";
    };
  };

  config = {
    systemd.network = {
      wait-online.enable = true;
      networks."10-wan" = {
        matchConfig.Name = "en* eth*";
        linkConfig.RequiredForOnline = "routable";

        address = [
          "${cfg.ipv4}/32"
          "${cfg.ipv6Prefix}1/64"
        ];

        networkConfig = {
          DHCP = false;
          IPv6AcceptRA = false;
        };

        routes = [
          {
            Destination = "0.0.0.0/0";
            Gateway = "172.31.1.1";
            GatewayOnLink = true;
          }
          {
            Destination = "::/0";
            Gateway = "fe80::1";
          }
        ];

        dns = ["185.12.64.1" "185.12.64.2"];
      };
    };
  };
}
