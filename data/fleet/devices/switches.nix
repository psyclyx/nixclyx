# Switch port assignments — the physical cabling reality.
#
# Each port is an attrset with:
#   vlan  = N;           — native/untagged VLAN (access port)
#   vlans = [N ...];     — tagged VLANs (trunk port)
#   meta  = { ... };     — optional: host, peer, description (documentation only)
#   {}                   — unused (disabled)
#
# Naming convention: <closet>-<role><seq>
#   MDF = server rack (living room west)
#   IDF = network cabinet (living room east)

let
  # Standard VLAN sets for trunk ports.
  internal = [10 25 30 31 50 100 110 240];
  all      = internal ++ [250];
in {
  # ── MDF (server rack) ────────────────────────────────────────────

  mdf-agg01 = {
    model = "CRS326-24S+2Q+RM";
    platform = "routeros";
    identity = "mdf-agg01";
    description = "10G SFP+ aggregation switch";
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
      # Lab host 10G NICs — 2 per host (data + prod)
      "sfp-sfpplus1"  = { vlan = 50; meta = { host = "lab-1"; description = "data"; }; };
      "sfp-sfpplus2"  = { vlan = 30; meta = { host = "lab-1"; description = "prod"; }; };
      "sfp-sfpplus3"  = { vlan = 50; meta = { host = "lab-2"; description = "data"; }; };
      "sfp-sfpplus4"  = { vlan = 30; meta = { host = "lab-2"; description = "prod"; }; };
      "sfp-sfpplus5"  = { vlan = 50; meta = { host = "lab-3"; description = "data"; }; };
      "sfp-sfpplus6"  = { vlan = 30; meta = { host = "lab-3"; description = "prod"; }; };
      "sfp-sfpplus7"  = { vlan = 50; meta = { host = "lab-4"; description = "data"; }; };
      "sfp-sfpplus8"  = { vlan = 30; meta = { host = "lab-4"; description = "prod"; }; };

      # Trunk to mdf-acc01 (CSS326 in same rack, dual SFP+ LACP)
      # No transit VLAN 250 — CSS326 is internal-only.
      "sfp-sfpplus9"  = { vlans = internal; meta.peer = "mdf-acc01"; };
      "sfp-sfpplus10" = { vlans = internal; meta.peer = "mdf-acc01"; };

      # Sigil workstation (main VLAN, LACP bond — two 10G links)
      "sfp-sfpplus11" = { vlan = 10; meta.host = "sigil"; };
      "sfp-sfpplus12" = { vlan = 10; meta.host = "sigil"; };
      "sfp-sfpplus13" = {};
      "sfp-sfpplus14" = {};
      "sfp-sfpplus15" = {};
      "sfp-sfpplus16" = {};
      "sfp-sfpplus17" = {};
      "sfp-sfpplus18" = {};
      "sfp-sfpplus19" = {};
      # Trunk to idf-dist01 (CRS305 in network cabinet)
      "sfp-sfpplus20" = { vlans = all; meta.peer = "idf-dist01"; };
      "sfp-sfpplus21" = {};
      "sfp-sfpplus22" = {};
      "sfp-sfpplus23" = {};
      # Trunk to mdf-brk01 (2.5G switch for iyr breakout)
      "sfp-sfpplus24" = { vlans = all; meta.peer = "mdf-brk01"; };
    };
  };

  mdf-acc01 = {
    model = "CSS326-24G-2S+RM";
    platform = "swos";
    identity = "mdf-acc01";
    description = "1G lab access switch";
    addresses.mgmt.ipv4 = "10.0.240.3";

    ports = {
      # Lab-1: BMC + 4 ethernet (5 ports per host)
      ether1  = { vlan = 240; meta.host = "lab-1"; meta.description = "BMC/iLO"; };
      ether2  = { vlan = 25;  meta.host = "lab-1"; meta.description = "infra"; };
      ether3  = { vlan = 31;  meta.host = "lab-1"; meta.description = "stage"; };
      ether4  = { vlan = 30;  meta.host = "lab-1"; meta.description = "prod"; };
      ether5  = { vlan = 30;  meta.host = "lab-1"; meta.description = "eno4 (second prod link)"; };

      # Lab-2
      ether6  = { vlan = 240; meta.host = "lab-2"; meta.description = "BMC/iLO"; };
      ether7  = { vlan = 25;  meta.host = "lab-2"; meta.description = "infra"; };
      ether8  = { vlan = 31;  meta.host = "lab-2"; meta.description = "stage"; };
      ether9  = { vlan = 30;  meta.host = "lab-2"; meta.description = "prod"; };
      ether10 = { vlan = 30;  meta.host = "lab-2"; meta.description = "eno4 (second prod link)"; };

      # Lab-3
      ether11 = { vlan = 240; meta.host = "lab-3"; meta.description = "BMC/iLO"; };
      ether12 = { vlan = 25;  meta.host = "lab-3"; meta.description = "infra"; };
      ether13 = { vlan = 31;  meta.host = "lab-3"; meta.description = "stage"; };
      ether14 = { vlan = 30;  meta.host = "lab-3"; meta.description = "prod"; };
      ether15 = { vlan = 30;  meta.host = "lab-3"; meta.description = "eno4 (second prod link)"; };

      # Lab-4
      ether16 = { vlan = 240; meta.host = "lab-4"; meta.description = "BMC/iLO"; };
      ether17 = { vlan = 25;  meta.host = "lab-4"; meta.description = "infra"; };
      ether18 = { vlan = 31;  meta.host = "lab-4"; meta.description = "stage"; };
      ether19 = { vlan = 30;  meta.host = "lab-4"; meta.description = "prod"; };
      ether20 = { vlan = 30;  meta.host = "lab-4"; meta.description = "eno4 (second prod link)"; };

      ether21 = {};
      ether22 = {};
      ether23 = {};
      ether24 = { vlan = 240; meta.description = "admin access"; };

      # SFP+ uplinks — bonded to CRS326
      "sfp-sfpplus1" = { vlans = internal; meta.peer = "mdf-agg01"; };
      "sfp-sfpplus2" = { vlans = internal; meta.peer = "mdf-agg01"; };
    };
  };

  # mdf-brk01: 2.5G managed switch providing iyr breakout.
  # iyr has two NICs (LAN + WAN) that need separate VLAN sets,
  # but the CRS326 only has one SFP+ port allocated.  This switch
  # splits the single trunk into per-NIC trunks.
  mdf-brk01 = {
    model = "SL902-SWTGW218AS";
    platform = "web-managed";
    identity = "mdf-brk01";
    description = "2.5G iyr breakout switch";
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

  # ── IDF (network cabinet, living room east) ──────────────────────

  idf-dist01 = {
    model = "CRS305-1G-4S+IN";
    platform = "routeros";
    identity = "idf-dist01";
    description = "Distribution switch + PoE-powered via ether1";
    addresses.mgmt.ipv4 = "10.0.240.4";

    ports = {
      # PoE-in only — disabled as a data port because idf-poe01 is a dumb
      # switch also connected via sfp-sfpplus3; enabling both = loop.
      "ether1" = {};
      # Trunk to mdf-agg01 (CRS326 in server rack, via LR east-west patch)
      "sfp-sfpplus1" = { vlans = all; meta.peer = "mdf-agg01"; };
      # WAN uplink — modem (untagged transit VLAN 250)
      "sfp-sfpplus2" = { vlan = 250; meta.description = "modem (WAN)"; };
      # Trunk to idf-poe01 (DAC, carries AP VLANs through dumb PoE switch)
      "sfp-sfpplus3" = { vlans = all; meta.peer = "idf-poe01"; };
      # Fireplace drop
      "sfp-sfpplus4" = { vlan = 10; meta.description = "fireplace drop"; };
    };
  };

  # ── IDF unmanaged PoE (documentation only) ───────────────────────

  idf-poe01 = {
    model = "XMG-105HP";
    platform = "unmanaged";
    identity = "idf-poe01";
    description = "2.5G PoE++ switch — no VLAN support, transparent L2";

    # No management IP — unmanaged switch.
    # All ports are in the same flat broadcast domain.
    # VLAN-tagged frames from APs pass through transparently.
    #
    # Port layout:
    #   SFP+     → idf-dist01 sfp-sfpplus3 (DAC, 10G)
    #   PoE 1    → idf-dist01 ether1 (short patch, PoE power to CRS305)
    #   PoE 2    → AP drop 1
    #   PoE 3    → AP drop 2
    #   PoE 4    → spare
    #   Non-PoE  → spare
  };
}
