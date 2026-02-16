{
  path = ["psyclyx" "nixos" "config" "hosts" "tleilax"];
  variant = ["psyclyx" "nixos" "host"];
  imports = [./network.nix ./wireguard.nix];
  config = {
    config,
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
                extraRecords = ''
                  $INCLUDE /var/lib/nsd/dynamic/psyclyx.net.acme
                '';
              };
            };
          };
          resolver = {
            enable = true;
            interfaces = ["10.157.0.1"];
            accessControl = ["10.157.0.0/24 allow" "10.0.0.0/24 allow"];
            localZones = {
              "psyclyx.net" = {
                type = "static";
                records = [
                  "tleilax.psyclyx.net. IN A 10.157.0.1"
                  "sigil.psyclyx.net. IN A 10.157.0.3"
                  "iyr.psyclyx.net. IN A 10.157.0.2"
                  "metrics.psyclyx.net. IN A 10.157.0.1"
                ];
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

    # Grant acme user access to NSD control keys
    systemd.services.nsd.serviceConfig.ExecStartPost = let
      script = pkgs.writeShellScript "nsd-control-acme-perms" ''
        chgrp acme /etc/nsd/nsd_control.key /etc/nsd/nsd_control.pem
        chmod g+r /etc/nsd/nsd_control.key /etc/nsd/nsd_control.pem
      '';
    in ["+${script}"];

    # Internal metrics vhost (bypasses psyclyx nginx module — needs DNS-01 cert)
    services.nginx.virtualHosts."metrics.psyclyx.net" = {
      useACMEHost = "psyclyx.net";
      forceSSL = true;
      listen = [
        { addr = "10.157.0.1"; port = 443; ssl = true; }
        { addr = "10.157.0.1"; port = 80; }
      ];
      locations."/".proxyPass = "http://127.0.0.1:2134";
    };

    # ACME wildcard cert for *.psyclyx.net via DNS-01
    security.acme.certs."psyclyx.net" = {
      domain = "psyclyx.net";
      extraDomainNames = ["*.psyclyx.net"];
      dnsProvider = "exec";
      credentialFiles."EXEC_PATH" = pkgs.writeText "acme-exec-path" "${acmeHook}";
      group = "nginx";
    };

    # Ensure ACME challenge file exists for NSD $INCLUDE
    systemd.tmpfiles.rules = [
      "d /var/lib/nsd/dynamic 0755 acme acme -"
      "f /var/lib/nsd/dynamic/psyclyx.net.acme 0644 acme acme -"
    ];
  };
}
