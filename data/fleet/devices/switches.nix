# Switch port assignments — the physical cabling reality.
#
# Each port maps to either:
#   { host; interface; }  — an access port for a host NIC
#   { type = "trunk"; peer; }  — a tagged trunk to another switch or router
#   { type = "access"; vlan; } — an access port for a non-host device (modem, AP)
#   { type = "unused"; }  — explicitly unassigned
#
# The network (VLAN) for host access ports is derived from the host's
# interface mapping in hosts/*.nix — the switch data says WHICH port,
# the host data says WHICH VLAN.  The generator joins them.
#
# Naming convention: <closet>-<role><seq>
#   MDF = server rack (living room west)
#   IDF = network cabinet (living room east)
{
  # ── MDF (server rack) ────────────────────────────────────────────

  mdf-agg01 = {
    model = "CRS326-24S+2Q+RM";
    platform = "routeros";
    identity = "mdf-agg01";
    description = "10G SFP+ aggregation switch";
    addresses.mgmt.ipv4 = "10.0.240.2";

    ports = {
      # Lab host 10G NICs — 2 per host (data + prod)
      "sfp-sfpplus1"  = { host = "lab-1"; interface = "data"; };
      "sfp-sfpplus2"  = { host = "lab-1"; interface = "prod"; };
      "sfp-sfpplus3"  = { host = "lab-2"; interface = "data"; };
      "sfp-sfpplus4"  = { host = "lab-2"; interface = "prod"; };
      "sfp-sfpplus5"  = { host = "lab-3"; interface = "data"; };
      "sfp-sfpplus6"  = { host = "lab-3"; interface = "prod"; };
      "sfp-sfpplus7"  = { host = "lab-4"; interface = "data"; };
      "sfp-sfpplus8"  = { host = "lab-4"; interface = "prod"; };

      # Trunk to mdf-acc01 (CSS326 in same rack, dual SFP+)
      "sfp-sfpplus9"  = { type = "trunk"; peer = "mdf-acc01"; };
      "sfp-sfpplus10" = { type = "trunk"; peer = "mdf-acc01"; };

      # Sigil workstation (main VLAN, LACP bond — two 10G links)
      "sfp-sfpplus11" = { host = "sigil"; interface = "main"; };
      "sfp-sfpplus12" = { host = "sigil"; interface = "main"; };
      "sfp-sfpplus13" = { type = "unused"; };
      "sfp-sfpplus14" = { type = "unused"; };
      "sfp-sfpplus15" = { type = "unused"; };
      "sfp-sfpplus16" = { type = "unused"; };
      "sfp-sfpplus17" = { type = "unused"; };
      "sfp-sfpplus18" = { type = "unused"; };
      "sfp-sfpplus19" = { type = "unused"; };
      # Trunk to idf-dist01 (CRS305 in network cabinet)
      "sfp-sfpplus20" = { type = "trunk"; peer = "idf-dist01"; };
      "sfp-sfpplus21" = { type = "unused"; };
      "sfp-sfpplus22" = { type = "unused"; };
      "sfp-sfpplus23" = { type = "unused"; };
      # Trunk to mdf-brk01 (2.5G switch for iyr breakout)
      "sfp-sfpplus24" = { type = "trunk"; peer = "mdf-brk01"; };
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
      ether1  = { host = "lab-1"; interface = "mgmt"; };
      ether2  = { host = "lab-1"; interface = "eno1"; };
      ether3  = { host = "lab-1"; interface = "eno2"; };
      ether4  = { host = "lab-1"; interface = "eno3"; };
      ether5  = { host = "lab-1"; interface = "eno4"; };

      # Lab-2
      ether6  = { host = "lab-2"; interface = "mgmt"; };
      ether7  = { host = "lab-2"; interface = "eno1"; };
      ether8  = { host = "lab-2"; interface = "eno2"; };
      ether9  = { host = "lab-2"; interface = "eno3"; };
      ether10 = { host = "lab-2"; interface = "eno4"; };

      # Lab-3
      ether11 = { host = "lab-3"; interface = "mgmt"; };
      ether12 = { host = "lab-3"; interface = "eno1"; };
      ether13 = { host = "lab-3"; interface = "eno2"; };
      ether14 = { host = "lab-3"; interface = "eno3"; };
      ether15 = { host = "lab-3"; interface = "eno4"; };

      # Lab-4
      ether16 = { host = "lab-4"; interface = "mgmt"; };
      ether17 = { host = "lab-4"; interface = "eno1"; };
      ether18 = { host = "lab-4"; interface = "eno2"; };
      ether19 = { host = "lab-4"; interface = "eno3"; };
      ether20 = { host = "lab-4"; interface = "eno4"; };

      # Unused 1G ports
      ether21 = { type = "unused"; };
      ether22 = { type = "unused"; };
      ether23 = { type = "unused"; };
      ether24 = { type = "access"; vlan = 240; description = "admin access"; };

      # SFP+ uplinks — bonded to CRS326
      "sfp-sfpplus1" = { type = "trunk"; peer = "mdf-agg01"; };
      "sfp-sfpplus2" = { type = "trunk"; peer = "mdf-agg01"; };
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

    # Port numbering matches the switch's web UI (Port 1-9).
    # Only 3 ports are in use; the rest are unused.
    ports = {
      port5 = { type = "trunk"; peer = "iyr"; description = "iyr WAN (enp3s0, transit VLAN)"; vlans = [250]; };
      port6 = { type = "trunk"; peer = "iyr"; description = "iyr LAN (enp1s0, all internal VLANs)"; };
      port9 = { type = "trunk"; peer = "mdf-agg01"; description = "uplink to CRS326 sfp-sfpplus24"; };

      port1 = { type = "unused"; };
      port2 = { type = "unused"; };
      port3 = { type = "unused"; };
      port4 = { type = "unused"; };
      port7 = { type = "unused"; };
      port8 = { type = "unused"; };
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
      # ether1 receives PoE power from idf-poe01 AND serves as
      # management access (VLAN 240) so we can always reach it.
      "ether1" = { type = "access"; vlan = 240; description = "management + PoE-in"; };
      # Trunk to mdf-agg01 (CRS326 in server rack, via LR east-west patch)
      "sfp-sfpplus1" = { type = "trunk"; peer = "mdf-agg01"; };

      # WAN uplink — modem (untagged transit VLAN 250)
      "sfp-sfpplus2" = { type = "access"; vlan = 250; description = "modem (WAN)"; };

      # Trunk to idf-poe01 (DAC, carries AP VLANs)
      "sfp-sfpplus3" = { type = "trunk"; peer = "idf-poe01"; };

      # Fireplace drop — 10G access port (main VLAN, currently unused)
      "sfp-sfpplus4" = { type = "access"; vlan = 10; description = "fireplace drop"; };
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
