{
  config,
  lib,
  pkgs,
  nixclyx,
  ...
}:
let
  eg = config.psyclyx.egregore;
  me = eg.entities.tleilax;
in
{
  imports = [ ./network.nix ];

  networking.hostName = "tleilax";

  fileSystems = {
    "/" = {
      device = "UUID=a5823c8f-07c7-41c5-ad9f-4782cb5ba154";
      fsType = "ext4";
    };
    "/boot" = {
      device = "UUID=C8F3-8E47";
      fsType = "vfat";
      options = [ "umask=0077" ];
    };
  };

  psyclyx.nixos = {
    hardware.presets.hpe.dl20-gen10.enable = true;

    network = {
      firewall = {
        enable = true;
        zones = {
          wg.interfaces = [ "wg0" ];
          mullvad.interfaces = [ "veth-mv0" ];
          public.interfaces = [ "bond0" ];
        };
        input = {
          wg.policy = "accept";
          mullvad = {
            policy = "drop";
            allowICMP = true;
            allowedTCPPorts = [ 8080 ]; # qBittorrent web UI
          };
          public = {
            policy = "drop";
            allowICMP = true;
            allowedTCPPorts =
              with config.psyclyx.nixos.network.ports;
              dns.tcp ++ haproxy-ingress.tcp ++ ssh.tcp;
            allowedUDPPorts = with config.psyclyx.nixos.network.ports; dns.udp ++ wireguard.udp;
          };
        };
        forward = [
          {
            from = "wg";
            to = "wg";
          }
          {
            from = "wg";
            to = "public";
          }
        ];
        masquerade = [
          {
            from = "wg";
            to = "public";
          }
        ];
      };

      dns = {
        authoritative = {
          ns = me.attrs.addresses.public.ipv4;
          interfaces = [
            me.attrs.addresses.public.ipv4
            me.attrs.addresses.public.ipv6
          ];
          port = 53;
          tsigKeyName = "acme-tleilax";
          zones = {
            "psyclyx.xyz" = {
              ttl = 3600;
              ddns = true;
            };
            "psyclyx.net" = {
              ttl = 3600;
              ddns = true;
            };
          };
        };
        resolver = {
          enable = true;
          interfaces = [ "10.157.0.1" ];
          accessControl = [
            "10.157.0.0/24 allow"
            "10.0.0.0/8 allow"
          ];
          forwardZones = {
            "0.10.in-addr.arpa" = {
              forward-addr = [ "10.157.0.2" ];
            };
          };
        };
      };
    };

    role = "server";

    services = {
      tailscale.exitNode = true;

      loki.enable = true;
      prometheus.server.enable = true;

      grafana = {
        enable = true;
        domain = "metrics.psyclyx.net";
        dashboards.enable = true;
      };

      nginx = {
        enable = true;
        acme.email = "me@psyclyx.xyz";
      };
    };
  };

  psyclyx.nixos.network.dns.authoritative.zones."stage.psyclyx.net" = {
    ttl = 300;
    ddns = true;
    extraRecords = ''
      @          IN A     ${me.attrs.addresses.public.ipv4}
      @          IN AAAA  ${me.attrs.addresses.public.ipv6}
    '';
  };
}
