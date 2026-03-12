{
  path = ["psyclyx" "nixos" "hosts" "tleilax"];
  variant = ["psyclyx" "nixos" "host"];
  imports = [./network.nix];
  config = {
    config,
    lib,
    pkgs,
    nixclyx,
    ...
  }: {
    networking.hostName = "tleilax";

    # WireGuard extras (topology module handles base wg0 config)
    boot.kernel.sysctl."net.ipv4.tcp_synack_retries" = 2; # default 5 — reduce SYN-ACK retransmit amplification
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

        ports.ssh = [17891];

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
            accessControl = ["10.157.0.0/24 allow" "10.157.10.0/24 allow" "10.0.0.0/24 allow"];
            localZones = {
              "psyclyx.net" = {
                type = "transparent";
                records = [
                  "metrics.psyclyx.net. IN A 10.157.0.1"
                  "s3.psyclyx.net. IN A 10.157.10.200"
                  "webdav.psyclyx.net. IN A 10.157.10.200"
                  "cache.psyclyx.net. IN A 10.157.10.200"
                ];
              };
            };
            forwardZones = {
              "home.psyclyx.net" = {
                forward-addr = ["10.157.0.2"];
              };
              "0.10.in-addr.arpa" = {
                forward-addr = ["10.157.0.2"];
              };
              "10.157.10.in-addr.arpa" = {
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
  };
}
