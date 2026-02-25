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
  }: let
    acmeHook = pkgs.writeShellScript "acme-dns-hook" ''
      action="$1"
      value="$3"
      ACME_FILE="/var/lib/nsd/dynamic/psyclyx.net.acme"
      case "$action" in
        present)
          echo "_acme-challenge IN TXT \"$value\"" >> "$ACME_FILE"
          ${pkgs.nsd}/bin/nsd-control reload psyclyx.net
          ;;
        cleanup)
          : > "$ACME_FILE"
          ${pkgs.nsd}/bin/nsd-control reload psyclyx.net
          ;;
      esac
    '';
  in {
    networking.hostName = "tleilax";

    # WireGuard extras (topology module handles base wg0 config)
    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
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

    # Handwritten firewall — tleilax is directly on the internet (no router),
    # so we replace the NixOS firewall with explicit nftables rules.
    # Everything is reachable over wg0; only public services on bond0.
    networking.firewall.enable = false;
    networking.nftables = {
      enable = true;
      checkRuleset = false; # wg0 doesn't exist in the build sandbox
      ruleset = let
        topo = config.psyclyx.topology;
        sshPorts = lib.concatMapStringsSep ", " toString config.psyclyx.nixos.network.ports.ssh;
      in ''
        table inet filter {
          chain input {
            type filter hook input priority 0; policy drop;

            iif lo accept
            iif wg0 accept

            ct state established,related accept
            ct state invalid drop

            ip protocol icmp icmp type echo-request accept
            ip6 nexthdr icmpv6 accept

            tcp dport { 53, 80, 443, ${sshPorts} } accept
            udp dport { 53, ${toString topo.wireguard.port} } accept
          }

          chain forward {
            type filter hook forward priority 0; policy accept;
          }

          chain output {
            type filter hook output priority 0; policy accept;
          }
        }
      '';
    };

    psyclyx.nixos = {
      hardware.presets.hpe.dl20-gen10.enable = true;

      network = {
        ports.ssh = [17891];

        dns = {
          authoritative = {
            ns = "199.255.18.171";
            interfaces = ["199.255.18.171" "2606:7940:32:26::10"];
            port = 53;
            zones = {
              "psyclyx.xyz" = {
                ttl = 3600;
                extraRecords = ''
                  vpn    IN A     199.255.18.171
                '';
              };
              "psyclyx.net" = {
                ttl = 3600;
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

    # NSD remote control for ACME DNS hook
    services.nsd.remoteControl.enable = true;

    # Generate remote control TLS certs if missing (NSD module doesn't auto-generate),
    # then inject ACME $INCLUDE after upstream preStart copies zone files from the store
    # (can't be in zone data directly — nsd-checkzone runs at build time in the sandbox)
    systemd.services.nsd.serviceConfig.WorkingDirectory = "/";
    systemd.services.nsd.serviceConfig.StateDirectoryMode = "0751";
    systemd.services.nsd.preStart = lib.mkMerge [
      (lib.mkBefore ''
        if [ ! -f /etc/nsd/nsd_server.pem ]; then
          PATH="${pkgs.openssl}/bin:$PATH" ${pkgs.nsd}/bin/nsd-control-setup
        fi
      '')
      (lib.mkAfter ''
        echo '$INCLUDE /dynamic/psyclyx.net.acme' >> /var/lib/nsd/zones/psyclyx.net
      '')
    ];

    # Grant acme user access to NSD control + server certs
    systemd.services.nsd.serviceConfig.ExecStartPost = let
      script = pkgs.writeShellScript "nsd-control-acme-perms" ''
        chgrp acme /etc/nsd/nsd_control.key /etc/nsd/nsd_control.pem /etc/nsd/nsd_server.pem
        chmod g+r /etc/nsd/nsd_control.key /etc/nsd/nsd_control.pem /etc/nsd/nsd_server.pem
      '';
    in ["+${script}"];

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

    # ACME wildcard cert for *.psyclyx.net via DNS-01
    security.acme.certs."psyclyx.net" = {
      domain = "psyclyx.net";
      extraDomainNames = ["*.psyclyx.net"];
      dnsProvider = "exec";
      credentialFiles."EXEC_PATH_FILE" = pkgs.writeText "acme-exec-path" "${acmeHook}";
      group = "nginx";
    };

    # Allow ACME renewal service to write challenge records into NSD zone
    systemd.services."acme-order-renew-psyclyx.net".serviceConfig.ReadWritePaths = ["/var/lib/nsd/dynamic"];

    # Ensure ACME challenge file exists for NSD $INCLUDE
    # /var/lib/nsd needs o+x so the acme user can traverse to /dynamic/
    systemd.tmpfiles.rules = [
      "d /var/lib/nsd 0751 nsd nsd -"
      "d /var/lib/nsd/dynamic 0775 nsd acme -"
      "f /var/lib/nsd/dynamic/psyclyx.net.acme 0664 acme nsd -"
    ];
  };
}
