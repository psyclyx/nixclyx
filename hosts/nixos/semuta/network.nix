{ config, lib, ... }:
let
  cfg = config.psyclyx.nixos.hosts.semuta.network;
  eg = config.psyclyx.egregore;
  me = eg.entities.semuta;
in
{
  options.psyclyx.nixos.hosts.semuta.network = {
    ipv4 = lib.mkOption {
      type = lib.types.str;
      default = me.host.publicIPv4;
      description = "Public IPv4 address.";
    };
    ipv6 = lib.mkOption {
      type = lib.types.str;
      default = me.host.publicIPv6;
      description = "Public IPv6 address.";
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
          "${cfg.ipv6}/64"
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

        dns = [
          "185.12.64.1"
          "185.12.64.2"
        ];
      };
    };
  };
}
