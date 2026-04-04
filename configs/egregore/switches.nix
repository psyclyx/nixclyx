# Network switches — RouterOS, SwOS, Sodola, and unmanaged devices.
let
  # Standard VLAN sets for port definitions.
  internal = [10 25 30 31 50 100 110 240];
  all      = internal ++ [250];
in {
  gate = "always";
  config = {
    entities = {
      mdf-agg01 = {
        type = "routeros";
        tags = ["switch" "mdf" "10g"];
        routeros = {
          model = "CRS326-24S+2Q+RM";
          identity = "mdf-agg01";
          addresses.mgmt.ipv4 = "10.0.240.2";

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

          ports = {
            "sfp-sfpplus1"  = { vlan = 50; meta = { host = "lab-1"; description = "data"; }; };
            "sfp-sfpplus2"  = { vlan = 30; meta = { host = "lab-1"; description = "prod"; }; };
            "sfp-sfpplus3"  = { vlan = 50; meta = { host = "lab-2"; description = "data"; }; };
            "sfp-sfpplus4"  = { vlan = 30; meta = { host = "lab-2"; description = "prod"; }; };
            "sfp-sfpplus5"  = { vlan = 50; meta = { host = "lab-3"; description = "data"; }; };
            "sfp-sfpplus6"  = { vlan = 30; meta = { host = "lab-3"; description = "prod"; }; };
            "sfp-sfpplus7"  = { vlan = 50; meta = { host = "lab-4"; description = "data"; }; };
            "sfp-sfpplus8"  = { vlan = 30; meta = { host = "lab-4"; description = "prod"; }; };
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

          ports = {
            ether1  = { vlan = 240; meta = { host = "lab-1"; description = "BMC/iLO"; }; };
            ether2  = { vlans = [10 25 31]; meta = { host = "lab-1"; description = "bond (eno1)"; }; };
            ether3  = { vlans = [10 25 31]; meta = { host = "lab-1"; description = "bond (eno2)"; }; };
            ether4  = { vlans = [10 25 31]; meta = { host = "lab-1"; description = "bond (eno3)"; }; };
            ether5  = { vlans = [10 25 31]; meta = { host = "lab-1"; description = "bond (eno4)"; }; };
            ether6  = { vlan = 240; meta = { host = "lab-2"; description = "BMC/iLO"; }; };
            ether7  = { vlans = [10 25 31]; meta = { host = "lab-2"; description = "bond (eno1)"; }; };
            ether8  = { vlans = [10 25 31]; meta = { host = "lab-2"; description = "bond (eno2)"; }; };
            ether9  = { vlans = [10 25 31]; meta = { host = "lab-2"; description = "bond (eno3)"; }; };
            ether10 = { vlans = [10 25 31]; meta = { host = "lab-2"; description = "bond (eno4)"; }; };
            ether11 = { vlan = 240; meta = { host = "lab-3"; description = "BMC/iLO"; }; };
            ether12 = { vlans = [10 25 31]; meta = { host = "lab-3"; description = "bond (eno1)"; }; };
            ether13 = { vlans = [10 25 31]; meta = { host = "lab-3"; description = "bond (eno2)"; }; };
            ether14 = { vlans = [10 25 31]; meta = { host = "lab-3"; description = "bond (eno3)"; }; };
            ether15 = { vlans = [10 25 31]; meta = { host = "lab-3"; description = "bond (eno4)"; }; };
            ether16 = { vlan = 240; meta = { host = "lab-4"; description = "BMC/iLO"; }; };
            ether17 = { vlans = [10 25 31]; meta = { host = "lab-4"; description = "bond (eno1)"; }; };
            ether18 = { vlans = [10 25 31]; meta = { host = "lab-4"; description = "bond (eno2)"; }; };
            ether19 = { vlans = [10 25 31]; meta = { host = "lab-4"; description = "bond (eno3)"; }; };
            ether20 = { vlans = [10 25 31]; meta = { host = "lab-4"; description = "bond (eno4)"; }; };
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
