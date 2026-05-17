# Network switches — RouterOS, SwOS, Sodola, and unmanaged devices.
let
  # Standard VLAN sets for port definitions.
  #
  # 30/31/50 (prod/stage/data) were removed in the 2026 storage-host
  # rework; the lab traffic now lives on 200/210 (storage/lab) with
  # mdf-agg01 doing L3 hardware-offloaded routing.
  internal = [10 25 100 110 200 210 240];
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

          # L3 routing — the switch is the gateway for storage (200) and
          # lab (210). Its main-VLAN IP is a transit-only address so the
          # default route to iyr (10.0.10.1) avoids hairpinning through
          # the mgmt VLAN.
          l3HwOffload = true;
          uplinkNetwork = "main";
          addresses = {
            mgmt.ipv4    = "10.0.240.2";
            main.ipv4    = "10.0.10.2";
            storage.ipv4 = "10.0.200.1";   # convention gateway (.1)
            lab.ipv4     = "10.0.210.1";
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

          # Lab hosts dropped their 1G bonds in the 2026 rework — all
          # lab traffic now lives on the 10G NICs via mdf-agg01. The
          # copper ports formerly carrying the bond are left unused
          # (the physical cables can stay plugged in; they just have
          # no VLAN assignment now).
          ports = {
            ether1  = { vlan = 240; meta = { host = "lab-1"; description = "BMC/iLO"; }; };
            ether2  = {};
            ether3  = {};
            ether4  = {};
            ether5  = {};
            ether6  = { vlan = 240; meta = { host = "lab-2"; description = "BMC/iLO"; }; };
            ether7  = {};
            ether8  = {};
            ether9  = {};
            ether10 = {};
            ether11 = { vlan = 240; meta = { host = "lab-3"; description = "BMC/iLO"; }; };
            ether12 = {};
            ether13 = {};
            ether14 = {};
            ether15 = {};
            ether16 = { vlan = 240; meta = { host = "lab-4"; description = "BMC/iLO"; }; };
            ether17 = {};
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
