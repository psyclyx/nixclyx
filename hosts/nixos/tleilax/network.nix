{ config, lib, ... }:
let
  cfg = config.psyclyx.nixos.hosts.tleilax.network;
  eg = config.psyclyx.egregore;
  me = eg.entities.tleilax;
in
{
  options.psyclyx.nixos.hosts.tleilax.network = {
    ipv4 = lib.mkOption {
      type = lib.types.str;
      default = me.host.publicIPv4;
      description = "Public IPv4 address.";
    };
    ipv6 = lib.mkOption {
      type = lib.types.str;
      description = "IPv6 prefix (e.g., '2606:7940:32:26::').";
    };
  };

  config = {
    systemd.network = {
      wait-online.enable = true;
      netdevs = {
        "20-bond0" = {
          netdevConfig = {
            Name = "bond0";
            Kind = "bond";
          };
          bondConfig = {
            Mode = "802.3ad";
            LACPTransmitRate = "fast";
            TransmitHashPolicy = "layer3+4";
            MIIMonitorSec = "1s";
          };
        };
      };

      networks = {
        "10-eno-disable" = {
          matchConfig.Name = "eno0 eno1";
          linkConfig.ActivationPolicy = "down";
        };
        "20-bond0-ports" = {
          matchConfig.Name = "ens1f0np0 ens1f1np1";
          networkConfig.Bond = "bond0";
        };

        "20-bond0" = {
          matchConfig.Name = "bond0";
          linkConfig.RequiredForOnline = "routable";

          address = [
            "${cfg.ipv4}/32"
            "${cfg.ipv6}10/120"
          ];

          networkConfig = {
            DHCP = false;
            IPv6AcceptRA = false;
          };

          routes = [
            {
              Destination = "::/0";
              Gateway = "${cfg.ipv6}1";
            }
            {
              Destination = "0.0.0.0/0";
              Gateway = "${cfg.ipv6}1";
            }
          ];

          dns = [
            "127.0.0.1"
            "::1"
          ];
        };
      };
    };
  };
}
