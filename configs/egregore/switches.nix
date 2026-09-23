# Network switches — RouterOS, SwOS, Sodola, and unmanaged devices.
let
  # Standard VLAN sets for port definitions.
  #
  # 30/31/50 (prod/stage/data) were removed in the 2026 storage-host
  # rework; the lab traffic now lives on 200/210 (storage/lab) with
  # mdf-agg01 doing L3 hardware-offloaded routing.
  #
  internal = [10 25 200 210 240];
  # WAN transit VLANs — L2-only, not modeled as network entities (they
  # have no internal subnet). 251 is Google Fiber (the primary IPv4
  # uplink), 250 is Xfinity (IPv6 + the IPv4 fallback); both land on
  # idf-dist01 (sfp4/sfp2). Both ride every `all` trunk and land tagged
  # on iyr's enp3s0 (via mdf-brk01 port5). Failover lives on iyr — see
  # hosts/nixos/iyr and modules/nixos/network/wan-failover.nix.
  wan      = [250 251];
  # LAN core transit (VLAN 252): the point-to-point iyr↔mdf-agg01 link for
  # the router-on-a-stick migration — the switch will L3-route inter-VLAN in
  # hardware and hand north-south to iyr for NAT over this VLAN. Carried only
  # on the iyr→mdf-brk01→mdf-agg01 path (iyr LAN port, the media-converter
  # uplink, and the CRS326 uplink); nothing else needs it. L3 endpoints +
  # the `core-transit` network entity land with the gateway migration.
  core     = [252];
  all      = internal ++ wan;
in {
  gate = "always";
  config = {
    entities = {
      mdf-agg01 = {
        
        tags = ["switch" "mdf" "10g" "l3"];
        routeros = {
          model = "CRS326-24S+2Q+RM";
          identity = "mdf-agg01";
          bridge.multicast.querier = true;

          # L3 routing — with l3-hw-offloading on, the chip routes every
          # VLAN below that this switch holds an address on. Which of
          # them it is the *canonical* gateway for is a separate fact,
          # stated by each network's own refs.gateway: storage (200)
          # and lab (210).
          l3HwOffload = true;
          # Marvell primary; the CRS326 also reports an Atheros switch2
          # that holds no L3 settings.
          primarySwitchChip = "switch1";
          # IPv6 L3 hw offload — added in RouterOS 7.6, shares the
          # IPv4 hw table so no incremental memory cost.
          l3HwSettings.ipv6Hw = true;
          # IPv6 software-level forwarding (`/ipv6 settings forward`)
          # defaults to no on RouterOS; needs to be on or hw offload
          # has nothing to do.
          ipv6Forward = true;
          # ULA addresses: per-network suffix from `ulaSubnetHex`, host
          # portion follows the IPv4 convention (.1 for the gateway
          # SVIs, .2 on main where iyr is the L3 gateway).
          addresses = {
            mgmt.ipv4    = "10.0.240.2";
            mgmt.ipv6    = "fd9a:e830:4b1e:f0::2";
            # .1 — the v4 gateway for main, which is why clients need no
            # reconfiguration. The ULA stays ::2: iyr remains main's v6
            # router and holds ::1.
            main.ipv4    = "10.0.10.1";
            main.ipv6    = "fd9a:e830:4b1e:a::2";
            # LAN core transit (/30) — iyr .1, agg .2. The switch's default
            # route still exits via main to iyr until the gateway migration
            # flips it here.
            # .1 — infra's v4 gateway. The ULA stays ::2: iyr remains
            # infra's v6 router and holds ::1, same split as main.
            infra.ipv4   = "10.0.25.1";
            infra.ipv6   = "fd9a:e830:4b1e:19::2";
            core-transit.ipv4 = "10.0.252.2";
            core-transit.ipv6 = "fd9a:e830:4b1e:fc::2";
            storage.ipv4 = "10.0.200.1";   # convention gateway (.1)
            storage.ipv6 = "fd9a:e830:4b1e:c8::1";
            lab.ipv4     = "10.0.210.1";
            lab.ipv6     = "fd9a:e830:4b1e:d2::1";
          };

          bonds = {
            bond-css326 = {
              mode = "802.3ad";
              slaves = ["sfp-sfpplus9" "sfp-sfpplus10"];
              comment = "CSS326 trunk";
            };
            bond-sigil = {
              mode = "802.3ad";
              lacpMode = "passive";
              slaves = ["sfp-sfpplus11" "sfp-sfpplus12"];
              comment = "Sigil";
            };
          };

          # Lab-host wiring is unchanged from before — each host's two
          # 10G NICs still land on the same SFP+ pair. Convention:
          # the host's sfpDataDev → storage (VLAN 200) and sfpProdDev →
          # lab (VLAN 210).
          ports = {
            "sfp-sfpplus1"  = { vlan = 200; refs.host = { target = "lab-1"; nic = "storage"; }; };
            "sfp-sfpplus2"  = { vlan = 210; refs.host = { target = "lab-1"; nic = "lab"; }; };
            "sfp-sfpplus3"  = { vlan = 200; refs.host = { target = "lab-2"; nic = "storage"; }; };
            "sfp-sfpplus4"  = { vlan = 210; refs.host = { target = "lab-2"; nic = "lab"; }; };
            "sfp-sfpplus5"  = { vlan = 200; refs.host = { target = "lab-3"; nic = "storage"; }; };
            "sfp-sfpplus6"  = { vlan = 210; refs.host = { target = "lab-3"; nic = "lab"; }; };
            "sfp-sfpplus7"  = { vlan = 200; refs.host = { target = "lab-4"; nic = "storage"; }; };
            "sfp-sfpplus8"  = { vlan = 210; refs.host = { target = "lab-4"; nic = "lab"; }; };
            "sfp-sfpplus9"  = { vlans = internal; refs.peer = { target = "mdf-acc01"; port = "sfp-sfpplus1"; }; };
            "sfp-sfpplus10" = { vlans = internal; refs.peer = { target = "mdf-acc01"; port = "sfp-sfpplus2"; }; };
            "sfp-sfpplus11" = { vlan = 10; refs.host = "sigil"; };
            "sfp-sfpplus12" = { vlan = 10; refs.host = "sigil"; };
            "sfp-sfpplus13" = {};
            "sfp-sfpplus14" = {};
            "sfp-sfpplus15" = {};
            "sfp-sfpplus16" = {};
            "sfp-sfpplus17" = {};
            "sfp-sfpplus18" = {};
            "sfp-sfpplus19" = {};
            "sfp-sfpplus20" = { vlans = all; refs.peer = { target = "idf-dist01"; port = "sfp-sfpplus1"; }; };
            "sfp-sfpplus21" = {};
            "sfp-sfpplus22" = {};
            "sfp-sfpplus23" = {};
            "sfp-sfpplus24" = { vlans = all ++ core; refs.peer = { target = "mdf-brk01"; port = "port9"; }; };
          };
        };
      };

      mdf-acc01 = {
        
        tags = ["switch" "mdf" "1g"];
        refs.uplink = "mdf-agg01";
        swos = {
          model = "CSS326-24G-2S+RM";
          identity = "mdf-acc01";
          addresses.mgmt.ipv4 = "10.0.240.3";

          # Lab hosts dropped the 1G LACP bonds in the 2026 rework. As a
          # "for now" fallback while the 10G NIC driver story is sorted
          # out, eno1 on each lab host is re-enabled on VLAN 10 (main)
          # as an access port — PXE, SSH, and tang reach travel here.
          # The remaining 1G ports (eno2-4) stay disabled.
          ports = {
            ether1  = { vlan = 240; refs.host = "lab-1-ilo"; };
            ether2  = { vlan = 10;  refs.host = { target = "lab-1"; nic = "main"; }; description = "1G fallback"; };
            ether3  = {};
            ether4  = {};
            ether5  = {};
            ether6  = { vlan = 240; refs.host = "lab-2-ilo"; };
            ether7  = { vlan = 10;  refs.host = { target = "lab-2"; nic = "main"; }; description = "1G fallback"; };
            ether8  = {};
            ether9  = {};
            ether10 = {};
            ether11 = { vlan = 240; refs.host = "lab-3-ilo"; };
            ether12 = { vlan = 10;  refs.host = { target = "lab-3"; nic = "main"; }; description = "1G fallback"; };
            ether13 = {};
            ether14 = {};
            ether15 = {};
            ether16 = { vlan = 240; refs.host = "lab-4-ilo"; };
            ether17 = { vlan = 10;  refs.host = { target = "lab-4"; nic = "main"; }; description = "1G fallback"; };
            ether18 = {};
            ether19 = {};
            ether20 = {};
            ether21 = {};
            ether22 = {};
            ether23 = {};
            ether24 = { vlan = 240; description = "admin access"; };
            "sfp-sfpplus1" = { vlans = internal; refs.peer = { target = "mdf-agg01"; port = "sfp-sfpplus9"; }; };
            "sfp-sfpplus2" = { vlans = internal; refs.peer = { target = "mdf-agg01"; port = "sfp-sfpplus10"; }; };
          };
        };
      };

      mdf-brk01 = {
        
        tags = ["switch" "mdf" "2.5g"];
        refs.uplink = "mdf-agg01";
        sodola = {
          model = "SL902-SWTGW218AS";
          identity = "mdf-brk01";
          addresses.mgmt.ipv4 = "10.0.240.6";

          ports = {
            port1 = {};
            port2 = {};
            port3 = {};
            port4 = {};
            # iyr's two NICs are trunk parents, not logical interfaces —
            # enp1s0 carries every internal VLAN as enp1s0.<vlan>, and
            # enp3s0 carries the WAN transits. Neither is a key in
            # host.interfaces, so these edges name the entity only and
            # say the rest in prose.
            port5 = { vlans = wan; refs.peer = "iyr"; description = "iyr WAN (enp3s0, transit VLANs 250/251)"; };
            port6 = { vlans = internal ++ core; refs.peer = "iyr"; description = "iyr LAN (enp1s0, internal VLANs + core transit 252)"; };
            port7 = {};
            port8 = {};
            port9 = { vlans = all ++ core; refs.peer = { target = "mdf-agg01"; port = "sfp-sfpplus24"; }; };
          };
        };
      };

      idf-dist01 = {
        
        tags = ["switch" "idf"];
        routeros = {
          model = "CRS305-1G-4S+IN";
          identity = "idf-dist01";
          addresses.mgmt.ipv4 = "10.0.240.4";

          ports = {
            ether1         = {};
            "sfp-sfpplus1" = { vlans = all; refs.peer = { target = "mdf-agg01"; port = "sfp-sfpplus20"; }; };
            "sfp-sfpplus2" = { vlan = 250; description = "Xfinity modem (WAN, IPv6 + IPv4 fallback)"; };
            "sfp-sfpplus3" = { vlans = all; refs.peer = "idf-poe01"; };
            "sfp-sfpplus4" = { vlan = 251; description = "Google Fiber ONT (primary IPv4 WAN)"; };
          };
        };
      };

      idf-poe01 = {
        
        tags = ["switch" "idf"];
        unmanaged = {
          model = "XMG-105HP";
          description = "2.5G PoE++ switch — no VLAN support, transparent L2";
        };
      };
    };
  };
}
