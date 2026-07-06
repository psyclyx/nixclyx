{ lib, config, ... }:
let
  eg = config.psyclyx.egregore;
in
{
  imports = [ ./dhcp.nix ];

  networking.hostName = "iyr";

  systemd.network.networks."31-enp3s0.${toString eg.conventions.transitVlan}".linkConfig.MTUBytes = 1500;

  # WAN2 (VLAN 251) — a second uplink brought in on idf-dist01 sfp4 and
  # trunked to iyr tagged alongside WAN1 (250) via mdf-brk01 port5. For
  # now this is validation-only: iyr pulls a DHCP lease and can source
  # pings out enp3s0.251 (e.g. `ping -I enp3s0.251 1.1.1.1`), but all of
  # its DHCP routes live in a dedicated table (251) reached only by an
  # oif policy rule, so they never touch the main default route (WAN1)
  # and no client/LAN traffic is ever routed here. Firewall posture is
  # the shared `wan` zone (enp3s0.251 is added there in the iyr host
  # entity): input drop + ICMP + DHCP-client only.
  #
  # The VLAN netdev + enp3s0 parent-list wiring come from the interfaces
  # module; only the L3/DHCP unit is hand-written (the generic module's
  # dhcp path installs into the main table, which we specifically don't
  # want here).
  psyclyx.nixos.network.interfaces.vlans."enp3s0.251" = { id = 251; parent = "enp3s0"; };
  systemd.network.networks."31-enp3s0.251" = {
    matchConfig.Name = "enp3s0.251";
    networkConfig.DHCP = "ipv4";
    dhcpV4Config = {
      RouteTable = 251;
      UseDNS = false;
      UseNTP = false;
      UseHostname = false;
      ClientIdentifier = "mac";
    };
    routingPolicyRules = [{
      OutgoingInterface = "enp3s0.251";
      Table = 251;
      Priority = 251;
    }];
    linkConfig = {
      MTUBytes = 1500;
      RequiredForOnline = "no";
    };
  };

  # L2-only listener VLANs (lab, storage) on enp1s0 come from
  # derived/l2-listeners.nix; parent-unit VLAN aggregation is done by
  # network/interfaces.nix so gateway + listener children all hang off
  # the same enp1s0 unit automatically.

  # Tang server config (bind + ACL) comes from derived/tang.nix, driven
  # by the iyr-tang egregore entity (configs/egregore/trust-root.nix).

  # node + smartctl exporter listen addresses come from
  # derived/monitoring.nix (driven by the host entity's exporters
  # declaration). snmp is iyr-specific and stays local.
  services.prometheus.exporters.snmp.listenAddress = "127.0.0.1";
  services.prometheus.listenAddress = "127.0.0.1";

  psyclyx.nixos = {
    boot.initrd-ssh.enable = true;

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

    # PXE-boot infrastructure for the lab. iyr serves the iPXE chainload
    # binary over TFTP + per-host netboot bundles over HTTP. The bind
    # addresses fall out of egregore: one per network where a PXE-mode
    # host advertises an interface and where iyr has an address (either
    # as that network's gateway or as an L2-only listener).
    derived.pxe.serve = true;

    network = {
      # Gateway config (lanInterface/wanInterface/MACs/initrdVlans/
      # DHCPv6 DUID/CAKE QoS rates) comes from iyr's host.gateway in
      # egregore via derived/gateway.nix.

      dhcp-ddns.enable = true;

      dns = {
        client.enable = true;
        zones = {
          enable = true;
          siteZone = {
            enable = true;
            # main first (iyr/sigil), then lab so lab hosts (no main
            # address since they live behind the L3 switch) still land
            # at <host>.apt.psyclyx.net via their lab-VLAN IP. Storage
            # stays out of the site apex (it's iSCSI-only, no off-rack
            # clients should resolve a host to its storage IP).
            networks = [ "main" "lab" ];
          };
        };
        resolver = {
          enable = true;
          # Listen list (gateway addresses + L2 listener addresses +
          # vpn + ::) comes from derived/dns-resolver.nix. Adding the
          # untagged trunk IP here because it's not modeled in egregore.
          interfaces = [ "10.0.0.11" ];
          accessControl = [
            "10.0.0.0/8 allow"
            "${eg.ipv6UlaPrefix}::/48 allow"
            "fe80::/10 allow"
            "::1/128 allow"
          ];
          # Cross-site forwarding auto-derived from egregore site refs.dns
          # by derived/dns-forwarding.nix.
        };
      };

      # Firewall (zones, input, forward, masquerade) is fully derived:
      # - Zone→interface from `network.zone` + `host.interfaces` (derived/firewall-policy.nix)
      # - Zone extras + input + masquerade from iyr's `host.firewall` (derived/firewall-host.nix)
      # - Forward rules from `globals.policy` (derived/firewall-policy.nix)
      # Nothing host-side beyond the enable flag.
      firewall.enable = true;
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
        bindAddress = (eg.entities.${config.networking.hostName}).attrs.addresses.infra.ipv4;
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
        pki = {
          enable = true;
          commonName = "psyclyx Internal CA";
          roles = [
            {
              name = "postgres-server";
              allowedDomains = "psyclyx.net";
            }
          ];
        };
      };
    };
  };

}
