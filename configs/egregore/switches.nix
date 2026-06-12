# Network switches — RouterOS, SwOS, Sodola, and unmanaged devices.
let
  # Standard VLAN sets for port definitions.
  #
  # 30/31/50 (prod/stage/data) were removed in the 2026 storage-host
  # rework; the lab traffic now lives on 200/210 (storage/lab) with
  # mdf-agg01 doing L3 hardware-offloaded routing.
  #
  # 220-223 (cluster-prod/stage/scratch/orch) added in the lab-v3
  # rework — these will only ever live on the rack fabric, but
  # carrying them on every internal trunk is harmless and avoids
  # per-trunk VLAN-list bookkeeping. Routed at mdf-agg01 (L3 HW
  # offload); access ports come online as lab hosts get NICs wired
  # per env in phase 3 of the rework.
  internal = [10 25 100 110 200 210 220 221 222 223 240];
  all      = internal ++ [250];
in {
  gate = "always";
  config = {
    entities = {
      mdf-agg01 = {
        type = "routeros";
        tags = ["switch" "mdf" "10g" "l3"];
        routeros = {
          model = "CRS326-24S+2Q+RM";
          identity = "mdf-agg01";
          bridge.multicast.querier = true;

          # L3 routing — the switch is the gateway for storage (200),
          # lab (210), and the cluster-* envs (220-223). Its main-VLAN
          # IP is a transit-only address so the default route to iyr
          # (10.0.10.1) avoids hairpinning through the mgmt VLAN.
          #
          # Cluster SVIs are seated for phase 2 of the lab-v3 rework;
          # access ports for them come online when lab hosts get NICs
          # wired per env (phase 3). Until then, the SVIs are routable
          # but unreachable — no traffic yet.
          l3HwOffload = true;
          # IPv6 L3 hw offload — added in RouterOS 7.6, shares the
          # IPv4 hw table so no incremental memory cost.
          l3HwSettings.ipv6Hw = true;
          # IPv6 software-level forwarding (`/ipv6 settings forward`)
          # defaults to no on RouterOS; needs to be on or hw offload
          # has nothing to do.
          ipv6Forward = true;
          uplinkNetwork = "main";
          # ULA addresses: per-network suffix from `ulaSubnetHex`, host
          # portion follows the IPv4 convention (.1 for the gateway
          # SVIs, .2 on main where iyr is the L3 gateway).
          addresses = {
            mgmt.ipv4    = "10.0.240.2";
            mgmt.ipv6    = "fd9a:e830:4b1e:f0::2";
            main.ipv4    = "10.0.10.2";
            main.ipv6    = "fd9a:e830:4b1e:a::2";
            storage.ipv4 = "10.0.200.1";   # convention gateway (.1)
            storage.ipv6 = "fd9a:e830:4b1e:c8::1";
            lab.ipv4     = "10.0.210.1";
            lab.ipv6     = "fd9a:e830:4b1e:d2::1";
            cluster-prod.ipv4    = "10.0.220.1";
            cluster-prod.ipv6    = "fd9a:e830:4b1e:dc::1";
            cluster-stage.ipv4   = "10.0.221.1";
            cluster-stage.ipv6   = "fd9a:e830:4b1e:dd::1";
            cluster-scratch.ipv4 = "10.0.222.1";
            cluster-scratch.ipv6 = "fd9a:e830:4b1e:de::1";
            cluster-orch.ipv4    = "10.0.223.1";
            cluster-orch.ipv6    = "fd9a:e830:4b1e:df::1";
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
            "sfp-sfpplus1"  = { vlan = 200; meta = { host = "lab-1"; description = "storage"; }; };
            "sfp-sfpplus2"  = { vlan = 210; meta = { host = "lab-1"; description = "lab"; }; };
            "sfp-sfpplus3"  = { vlan = 200; meta = { host = "lab-2"; description = "storage"; }; };
            "sfp-sfpplus4"  = { vlan = 210; meta = { host = "lab-2"; description = "lab"; }; };
            "sfp-sfpplus5"  = { vlan = 200; meta = { host = "lab-3"; description = "storage"; }; };
            "sfp-sfpplus6"  = { vlan = 210; meta = { host = "lab-3"; description = "lab"; }; };
            "sfp-sfpplus7"  = { vlan = 200; meta = { host = "lab-4"; description = "storage"; }; };
            "sfp-sfpplus8"  = { vlan = 210; meta = { host = "lab-4"; description = "lab"; }; };
            "sfp-sfpplus9"  = { vlans = internal; meta.peer = "mdf-acc01"; };
            "sfp-sfpplus10" = { vlans = internal; meta.peer = "mdf-acc01"; };
            "sfp-sfpplus11" = { vlan = 10; meta.host = "sigil"; };
            "sfp-sfpplus12" = { vlan = 10; meta.host = "sigil"; };
            "sfp-sfpplus13" = {};
            "sfp-sfpplus14" = {};
            "sfp-sfpplus15" = {};
            "sfp-sfpplus16" = {};
            "sfp-sfpplus17" = {};
            "sfp-sfpplus18" = {};
            "sfp-sfpplus19" = {};
            "sfp-sfpplus20" = { vlans = all; meta.peer = "idf-dist01"; };
            "sfp-sfpplus21" = {};
            "sfp-sfpplus22" = {};
            "sfp-sfpplus23" = {};
            "sfp-sfpplus24" = { vlans = all; meta.peer = "mdf-brk01"; };
          };
        };
      };

      mdf-acc01 = {
        type = "swos";
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
            ether1  = { vlan = 240; meta = { host = "lab-1"; description = "BMC/iLO"; }; };
            ether2  = { vlan = 10;  meta = { host = "lab-1"; description = "eno1 (1G fallback)"; }; };
            ether3  = {};
            ether4  = {};
            ether5  = {};
            ether6  = { vlan = 240; meta = { host = "lab-2"; description = "BMC/iLO"; }; };
            ether7  = { vlan = 10;  meta = { host = "lab-2"; description = "eno1 (1G fallback)"; }; };
            ether8  = {};
            ether9  = {};
            ether10 = {};
            ether11 = { vlan = 240; meta = { host = "lab-3"; description = "BMC/iLO"; }; };
            ether12 = { vlan = 10;  meta = { host = "lab-3"; description = "eno1 (1G fallback)"; }; };
            ether13 = {};
            ether14 = {};
            ether15 = {};
            ether16 = { vlan = 240; meta = { host = "lab-4"; description = "BMC/iLO"; }; };
            ether17 = { vlan = 10;  meta = { host = "lab-4"; description = "eno1 (1G fallback)"; }; };
            ether18 = {};
            ether19 = {};
            ether20 = {};
            ether21 = {};
            ether22 = {};
            ether23 = {};
            ether24 = { vlan = 240; meta.description = "admin access"; };
            "sfp-sfpplus1" = { vlans = internal; meta.peer = "mdf-agg01"; };
            "sfp-sfpplus2" = { vlans = internal; meta.peer = "mdf-agg01"; };
          };
        };
      };

      mdf-brk01 = {
        type = "sodola";
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
            port5 = { vlans = [250]; meta = { peer = "iyr"; description = "iyr WAN (enp3s0, transit VLAN)"; }; };
            port6 = { vlans = internal; meta = { peer = "iyr"; description = "iyr LAN (enp1s0, all internal VLANs)"; }; };
            port7 = {};
            port8 = {};
            port9 = { vlans = all; meta = { peer = "mdf-agg01"; description = "uplink to CRS326 sfp-sfpplus24"; }; };
          };
        };
      };

      idf-dist01 = {
        type = "routeros";
        tags = ["switch" "idf"];
        routeros = {
          model = "CRS305-1G-4S+IN";
          identity = "idf-dist01";
          addresses.mgmt.ipv4 = "10.0.240.4";

          ports = {
            ether1         = {};
            "sfp-sfpplus1" = { vlans = all; meta.peer = "mdf-agg01"; };
            "sfp-sfpplus2" = { vlan = 250; meta.description = "modem (WAN)"; };
            "sfp-sfpplus3" = { vlans = all; meta.peer = "idf-poe01"; };
            "sfp-sfpplus4" = { vlan = 10; meta.description = "fireplace drop"; };
          };
        };
      };

      idf-poe01 = {
        type = "unmanaged";
        tags = ["switch" "idf"];
        unmanaged = {
          model = "XMG-105HP";
          description = "2.5G PoE++ switch — no VLAN support, transparent L2";
        };
      };
    };
  };
}
