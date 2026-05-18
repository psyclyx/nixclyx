{ lib, config, ... }:
let
  eg = config.psyclyx.egregore;

  # VLAN-keyed iteration. Only networks for which iyr is the gateway —
  # switch-routed networks (storage, lab) live downstream of the CRS326
  # and don't get a VLAN interface here. Overlays (vpn) excluded.
  networkEntities = lib.filterAttrs
    (_: e:
      e.type == "network"
      && e.network.vlan != null
      && (e.attrs.gatewayRef or null) == "iyr")
    eg.entities;
  sortedNets = lib.sort (a: b: a.network.vlan < b.network.vlan) (lib.attrValues networkEntities);

  dhcpVlans = lib.sort builtins.lessThan (lib.mapAttrsToList (_: e: e.network.vlan) networkEntities);
in
{
  imports = [ ./dhcp.nix ];

  networking.hostName = "iyr";

  systemd.network.networks."31-enp3s0.${toString eg.conventions.transitVlan}".linkConfig.MTUBytes = 1500;

  # gateway.nix's "30-enp1s0" unit only lists VLANs iyr gateways in its
  # `vlan = [...]`. We need the L2-only listener VLANs (lab, storage)
  # attached too; list-merge appends.
  systemd.network.networks."30-enp1s0".vlan = [ "enp1s0.210" "enp1s0.200" ];

  # Tang server for clevis-based ZFS unlock on lab hosts. Lab-4's
  # initrd reaches us via the JWE-embedded URL on our lab-VLAN IP;
  # clients on main route there via mdf-agg01. ACL allows both lab
  # and main subnets to cover the "for now" eno1 fallback path while
  # the 10G driver story is unresolved.
  services.tang = let
    labNet  = eg.entities.lab.attrs;
    mainNet = eg.entities.main.attrs;
  in {
    enable = true;
    listenStream = [ "${eg.entities.iyr.host.addresses.lab.ipv4}:7654" ];
    ipAddressAllow = [
      "${labNet.network4}/${toString labNet.prefixLen}"
      "${mainNet.network4}/${toString mainNet.prefixLen}"
    ];
  };

  services.prometheus.exporters.node.listenAddress = eg.entities.iyr.host.addresses.vpn.ipv4;
  services.prometheus.exporters.smartctl.listenAddress = eg.entities.iyr.host.addresses.vpn.ipv4;
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
    topology.pxe.serve = true;

    network = {
      # iyr is an L2-only DHCP listener on the switch-routed VLANs
      # (lab/storage — gateway'd by mdf-agg01, not iyr). The gateway
      # projection skips these networks, so we add the VLAN netdevs +
      # IPs by hand here. The gateway module's `vlan = [...]` list on
      # the lan-interface network unit only includes networks iyr
      # gateways, so we also extend it with the enp1s0.<vlan> child
      # devices below in systemd.network.networks.
      interfaces = {
        vlans."enp1s0.210" = { id = 210; parent = "enp1s0"; };
        networks."enp1s0.210" = {
          addresses = [ "10.0.210.2/24" ];
          requiredForOnline = "no";
        };
        vlans."enp1s0.200" = { id = 200; parent = "enp1s0"; };
        networks."enp1s0.200" = {
          # Storage anchor so Kea has a socket on VLAN 200 for the
          # storage pool's reservations. No host-side service uses this
          # address — clients route to mdf-agg01 (10.0.200.1) for L3.
          addresses = [ "10.0.200.2/24" ];
          requiredForOnline = "no";
          # MTU 9000 to match the storage VLAN — DHCP packets are tiny,
          # but bringing the interface up at 1500 would tag every frame
          # arriving from storage clients as "frame too big" if anything
          # ever tried to push iSCSI through this listener by accident.
          mtu = 9000;
        };
      };

      gateway = {
        enable = true;
        lanInterface = "enp1s0";
        wanInterface = "enp3s0";
        lanAddress = "10.0.0.11/24";
        lanMac = "c8:ff:bf:06:2c:4e";
        wanMac = "c8:ff:bf:06:2c:4d";
        initrdVlans = [
          "main"
          "mgmt"
        ];
        initrd.kernelModules = [
          "8021q"
          "igc"
        ];
        transitDhcpV6.duidRawData = "e7:13:f8:92:37:c5:be:76";
      };

      cake-qos = {
        enable = true;
        interface = "enp3s0.${toString eg.conventions.transitVlan}";
        download = {
          min = 1400000;
          base = 2000000;
          max = 2280000;
        };
        upload = {
          min = 700000;
          base = 1400000;
          max = 2280000;
        };
      };

      dhcp-ddns.enable = true;

      dns = {
        client.enable = true;
        zones = {
          enable = true;
          gatewayHostname = "iyr";
          siteZone = {
            enable = true;
            # main first (iyr/sigil), then lab so lab hosts (no main
            # address since they live behind the L3 switch) still land
            # at <host>.apt.psyclyx.net via their lab-VLAN IP.
            networks = [ "main" "lab" ];
          };
        };
        resolver = {
          enable = true;
          interfaces = [
            "10.0.0.11"
          ]
          ++ map (e: e.attrs.gateway4) sortedNets
          ++ [ "10.157.0.2" ]
          ++ map (e: e.attrs.gateway6) sortedNets
          ++ [ "::" ];
          accessControl = [
            "10.0.0.0/8 allow"
            "${eg.ipv6UlaPrefix}::/48 allow"
            "fe80::/10 allow"
            "::1/128 allow"
          ];
          # Cross-site forwarding auto-derived from egregore site refs.dns
          # by topology/dns-forwarding.nix.
        };
      };

      firewall =
        let
          vlanIface = id: "enp1s0.${builtins.toString id}";
          # `enp1s0.210` / `enp1s0.200` are included even though iyr
          # doesn't gateway those VLANs (the gateway projection filters
          # them out of dhcpVlans). iyr is on lab + storage as an
          # L2-only DHCP listener; firewall-wise they're regular LAN
          # interfaces.
          internal = [ "enp1s0" "enp1s0.210" "enp1s0.200" ] ++ map vlanIface dhcpVlans;
        in
        {
          enable = true;
          zones = {
            lan.interfaces = internal;
            wg.interfaces = [ "wg0" ];
            wan.interfaces = [ "enp3s0.${toString eg.conventions.transitVlan}" ];
          };
          input = {
            lan.policy = "accept";
            wg.policy = "accept";
            wan = {
              policy = "drop";
              allowICMP = true;
              allowedTCPPorts = config.psyclyx.nixos.network.ports.ssh.tcp;
              rules = [
                {
                  "udp sport" = 67;
                  "udp dport" = 68;
                  comment = "DHCPv4 client";
                }
                {
                  "udp dport" = 546;
                  comment = "DHCPv6 client";
                }
              ];
            };
          };
          forward = [
            { from = "lan"; to = "wan"; }
            { from = "lan"; to = "lan"; }
            { from = "wg";  to = "lan"; }
            { from = "wg";  to = "wan"; }
            { from = "lan"; to = "wg"; }
          ];
          masquerade = [
            { from = "lan"; to = "wan"; }
            # WG-routed traffic to apt VLANs needs source NAT: hub-side
            # peers (tleilax et al.) can't be reached symmetrically by lab
            # hosts replying directly via their own WG tunnel — the WG
            # cryptokey check at the hub drops sources outside the peer's
            # AllowedIPs. Masquerading at iyr makes apt-side traffic look
            # like it originated locally, so replies stay on apt-LAN and
            # come back through iyr.
            { from = "wg"; to = "lan"; }
          ];
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
        bindAddress = eg.entities.infra.attrs.gateway4;
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
