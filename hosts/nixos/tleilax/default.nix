{ config, lib, pkgs, nixclyx, ... }: {
  imports = [./network.nix];

  networking.hostName = "tleilax";

  # WireGuard extras (topology module handles base wg0 config)
  systemd.network.networks."30-wg0" = {
    address = ["10.0.10.2/24"];
    routes = [{Destination = "10.0.0.0/24";}];
  };

  fileSystems = {
    "/" = {
      device = "UUID=a5823c8f-07c7-41c5-ad9f-4782cb5ba154";
      fsType = "ext4";
    };
    "/boot" = {
      device = "UUID=C8F3-8E47";
      fsType = "vfat";
      options = ["umask=0077"];
    };
  };

  psyclyx.nixos = {
    hardware.presets.hpe.dl20-gen10.enable = true;

    network = {
      firewall = {
        enable = true;
        zones = {
          wg.interfaces = ["wg0"];
          mullvad.interfaces = ["veth-mv0"];
          public.interfaces = ["bond0"];
        };
        input = {
          wg.policy = "accept";
          mullvad = {
            policy = "drop";
            allowICMP = true;
            allowedTCPPorts = [8080]; # qBittorrent web UI
          };
          public = {
            policy = "drop";
            allowICMP = true;
            allowedTCPPorts = with config.psyclyx.nixos.network.ports;
              dns.tcp ++ nginx.tcp ++ ssh.tcp;
            allowedUDPPorts = with config.psyclyx.nixos.network.ports;
              dns.udp ++ wireguard.udp;
          };
        };
        forward = [
          {from = "wg"; to = "wg";}
          {from = "wg"; to = "public";}
        ];
        masquerade = [
          {from = "wg"; to = "public";}
        ];
      };

      dns = {
        authoritative = {
          ns = "199.255.18.171";
          interfaces = ["199.255.18.171" "2606:7940:32:26::10"];
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
          interfaces = ["10.157.0.1"];
          accessControl = ["10.157.0.0/24 allow" "10.0.0.0/8 allow"];
          localZones = {
            "psyclyx.net" = {
              type = "transparent";
              records = [
                "metrics.psyclyx.net. IN A 10.157.0.1"
                "s3.psyclyx.net. IN A 10.0.25.200"
                "webdav.psyclyx.net. IN A 10.0.25.200"
                "cache.psyclyx.net. IN A 10.0.25.200"
                "ha.psyclyx.net. IN A 10.157.0.1"
              ];
            };
          };
          forwardZones = {
            "apt.psyclyx.net" = {
              forward-addr = ["10.157.0.2"];
            };
            "0.10.in-addr.arpa" = {
              forward-addr = ["10.157.0.2"];
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
        virtualHosts = {
          "docs.psyclyx.xyz" = {
            root = nixclyx.docs;
          };
        };
      };
    };
  };

  # ACME wildcard cert for *.stage.psyclyx.net via DNS-01 (RFC 2136 → Knot)
  security.acme.certs."stage.psyclyx.net" = let
    authCfg = config.psyclyx.nixos.network.dns.authoritative;
  in {
    domain = "stage.psyclyx.net";
    extraDomainNames = ["*.stage.psyclyx.net"];
    dnsProvider = "rfc2136";
    credentialFiles = {
      "RFC2136_NAMESERVER_FILE" = pkgs.writeText "rfc2136-ns-stage" "${builtins.head authCfg.interfaces}:${toString authCfg.port}";
      "RFC2136_TSIG_ALGORITHM_FILE" = pkgs.writeText "rfc2136-algo-stage" "hmac-sha256.";
      "RFC2136_TSIG_KEY_FILE" = pkgs.writeText "rfc2136-keyname-stage" authCfg.tsigKeyName;
      "RFC2136_TSIG_SECRET_FILE" = authCfg.tsigSecretFile;
    };
    group = "nginx";
  };

  # Stage ingress — tleilax reverse proxies to apartment stage VIP
  services.nginx.virtualHosts."angelbeats.stage.psyclyx.net" = {
    useACMEHost = "stage.psyclyx.net";
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://10.0.31.200:80";
      proxyWebsockets = true;
    };
  };

  # DNS: stage.psyclyx.net zone (DDNS for iyr to add records)
  psyclyx.nixos.network.dns.authoritative.zones."stage.psyclyx.net" = {
    ttl = 300;
    ddns = true;
    extraRecords = ''
      @          IN A     199.255.18.171
      @          IN AAAA  2606:7940:32:26::10
      angelbeats IN A     199.255.18.171
      angelbeats IN AAAA  2606:7940:32:26::10
    '';
  };

  # ACME wildcard cert for *.psyclyx.net via DNS-01 (RFC 2136 → Knot)
  security.acme.certs."psyclyx.net" = let
    authCfg = config.psyclyx.nixos.network.dns.authoritative;
  in {
    domain = "psyclyx.net";
    extraDomainNames = ["*.psyclyx.net"];
    dnsProvider = "rfc2136";
    credentialFiles = {
      "RFC2136_NAMESERVER_FILE" = pkgs.writeText "rfc2136-ns" "${builtins.head authCfg.interfaces}:${toString authCfg.port}";
      "RFC2136_TSIG_ALGORITHM_FILE" = pkgs.writeText "rfc2136-algo" "hmac-sha256.";
      "RFC2136_TSIG_KEY_FILE" = pkgs.writeText "rfc2136-keyname" authCfg.tsigKeyName;
      "RFC2136_TSIG_SECRET_FILE" = authCfg.tsigSecretFile;
    };
    group = "nginx";
  };

  # Home Assistant reverse proxy
  services.nginx.virtualHosts."ha.psyclyx.net" = {
    useACMEHost = "psyclyx.net";
    forceSSL = true;
    listen = [
      { addr = "10.157.0.1"; port = 443; ssl = true; }
      { addr = "10.157.0.1"; port = 80; }
    ];
    locations."/" = {
      proxyPass = "http://10.0.110.100:8123";
      proxyWebsockets = true;
    };
  };

  # Internal metrics vhost (bypasses psyclyx nginx module — needs DNS-01 cert)
  services.nginx.virtualHosts."metrics.psyclyx.net" = {
    useACMEHost = "psyclyx.net";
    forceSSL = true;
    listen = [
      {
        addr = "10.157.0.1";
        port = 443;
        ssl = true;
      }
      {
        addr = "10.157.0.1";
        port = 80;
      }
    ];
    locations."/".proxyPass = "http://127.0.0.1:2134";
  };
}
