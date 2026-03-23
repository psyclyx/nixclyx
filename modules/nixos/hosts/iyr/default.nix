{
  path = ["psyclyx" "nixos" "hosts" "iyr"];
  variant = ["psyclyx" "nixos" "host"];
  imports = [./networkd.nix ./dhcp.nix ./dns.nix];
  config = {
    lib,
    config,
    ...
  }: let
    topo = config.psyclyx.topology;
    dt = topo.enriched;
    sortedNets = map (vlan:
      dt.networks.${dt.vlanNameMap.${toString vlan}})
    dt.dhcpVlans;
  in {
    networking.hostName = "iyr";

    # Restrict metrics to VPN interface only.  Binding to the WireGuard
    # address is the actual enforcement point.
    services.prometheus.exporters.node.listenAddress = topo.hosts.iyr.addresses.vpn.ipv4;
    services.prometheus.exporters.smartctl.listenAddress = topo.hosts.iyr.addresses.vpn.ipv4;
    # SNMP exporter is only queried by the local prometheus instance.
    services.prometheus.exporters.snmp.listenAddress = "127.0.0.1";
    # Collector's own prometheus port — nothing external needs to reach it.
    services.prometheus.listenAddress = "127.0.0.1";

    psyclyx.nixos = {
      boot = {
        initrd-ssh.enable = true;
      };

      filesystems.layouts.bcachefs-pool = {
        enable = true;
        UUID = {
          root = "0b6d93c8-c6d3-4243-9413-25543a093c65";
          boot = "0289-61AC";
        };
      };

      hardware = {
        cpu.intel.enable = true;
        gpu.intel.enable = true;
      };

      network.dns = {
        client.enable = true;
        resolver = {
          enable = true;
          interfaces =
            ["10.0.0.11"]
            ++ map (net: net.gateway4) sortedNets
            ++ ["10.157.0.2"]
            ++ map (net: net.gateway6) sortedNets
            ++ ["::"];
          accessControl = [
            "10.0.0.0/8 allow"
            "${topo.ipv6UlaPrefix}::/48 allow"
            "fe80::/10 allow"
            "::1/128 allow"
          ];
          forwardZones = {
            "psyclyx.net" = {
              forward-addr = ["10.157.0.1"];
            };
          };
        };
      };

      role = "server";

      services = {
        prometheus.collector.enable = true;
        kiosk = {
          enable = true;
          url = "https://metrics.psyclyx.net";
        };
        openbao-seal-oracle = {
          enable = true;
          bindAddress = dt.networks.infra.gateway4;
          tpm.enable = true;
          seal = {
            type = "pkcs11";
            secretField = "pin";
            lib = "/run/current-system/sw/lib/libtpm2_pkcs11.so";
            slot = "1";
            key_label = "openbao-unseal";
            mechanism = "0x00000009";
            generate_key = "false";
          };
          serviceEnvironment = {
            TPM2_PKCS11_STORE = "/var/lib/openbao-seal/tpm2-pkcs11";
            TPM2_PKCS11_BACKEND = "esysdb";
          };
          configure = ''
            if ! OUTPUT=$(bao secrets enable pki 2>&1); then
              if echo "$OUTPUT" | grep -q "path is already in use"; then
                echo "PKI engine already enabled"
              else
                echo "Failed to enable PKI engine: $OUTPUT" >&2
                exit 1
              fi
            fi

            bao secrets tune -max-lease-ttl=87600h pki

            if ! bao read pki/cert/ca >/dev/null 2>&1; then
              bao write pki/root/generate/internal \
                common_name="psyclyx Internal CA" \
                ttl=87600h
            fi

            bao write pki/roles/postgres-server \
              allowed_domains="psyclyx.net" \
              allow_subdomains=true \
              allow_ip_sans=true \
              max_ttl=720h
          '';
        };
      };
    };
  };
}
