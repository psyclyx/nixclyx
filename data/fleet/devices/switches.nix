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

      # Trunk to mdf-acc01 (CSS326 in same rack)
      "sfp-sfpplus9"  = { type = "trunk"; peer = "mdf-acc01"; };

      # Trunk to idf-dist01 (CRS305 in network cabinet, via LR east-west patch)
      "sfp-sfpplus10" = { type = "trunk"; peer = "idf-dist01"; };

      # Sigil workstation (main VLAN, single 10G link)
      "sfp-sfpplus11" = { host = "sigil"; interface = "main"; };

      # Unused
      "sfp-sfpplus12" = { type = "unused"; };
      "sfp-sfpplus13" = { type = "unused"; };
      "sfp-sfpplus14" = { type = "unused"; };
      "sfp-sfpplus15" = { type = "unused"; };
      "sfp-sfpplus16" = { type = "unused"; };
      "sfp-sfpplus17" = { type = "unused"; };
      "sfp-sfpplus18" = { type = "unused"; };
      "sfp-sfpplus19" = { type = "unused"; };
      "sfp-sfpplus20" = { type = "unused"; };
      "sfp-sfpplus21" = { type = "unused"; };
      "sfp-sfpplus22" = { type = "unused"; };
      "sfp-sfpplus23" = { type = "unused"; };
      "sfp-sfpplus24" = { type = "unused"; };
    };
  };

  mdf-acc01 = {
    model = "CSS326-24G-2S+RM";
    platform = "swos";
    identity = "mdf-acc01";
    description = "1G lab access switch";
    addresses.mgmt.ipv4 = "10.0.240.3";

    ports = {
      # Lab host 1G NICs — eno1 (infra) + eno2 (stage) per host
      ether1  = { host = "lab-1"; interface = "infra"; };
      ether2  = { host = "lab-1"; interface = "stage"; };
      ether3  = { host = "lab-2"; interface = "infra"; };
      ether4  = { host = "lab-2"; interface = "stage"; };
      ether5  = { host = "lab-3"; interface = "infra"; };
      ether6  = { host = "lab-3"; interface = "stage"; };
      ether7  = { host = "lab-4"; interface = "infra"; };
      ether8  = { host = "lab-4"; interface = "stage"; };

      # Lab host iLO BMCs — mgmt VLAN
      ether9  = { host = "lab-1"; interface = "mgmt"; };
      ether10 = { host = "lab-2"; interface = "mgmt"; };
      ether11 = { host = "lab-3"; interface = "mgmt"; };
      ether12 = { host = "lab-4"; interface = "mgmt"; };

      # iyr LAN trunk — all VLANs tagged
      ether13 = { type = "trunk"; peer = "iyr"; };

      # Unused 1G ports
      ether14 = { type = "unused"; };
      ether15 = { type = "unused"; };
      ether16 = { type = "unused"; };
      ether17 = { type = "unused"; };
      ether18 = { type = "unused"; };
      ether19 = { type = "unused"; };
      ether20 = { type = "unused"; };
      ether21 = { type = "unused"; };
      ether22 = { type = "unused"; };
      ether23 = { type = "unused"; };
      ether24 = { type = "unused"; };

      # SFP+ uplinks
      "sfp-sfpplus1" = { type = "trunk"; peer = "mdf-agg01"; };
      "sfp-sfpplus2" = { type = "unused"; };
    };
  };

  # ── IDF (network cabinet, living room east) ──────────────────────

  idf-dist01 = {
    model = "CRS305-1G-4S+IN";
    platform = "routeros";
    identity = "idf-dist01";
    description = "Distribution switch + PoE-powered via ether1";
    addresses.mgmt.ipv4 = "10.0.240.4";

    # ether1 is NOT on the bridge — it only receives PoE power from
    # idf-poe01 and sits in the same L2 domain as the AP ports.
    # Management is via vlan240 on the bridge (same as mdf-agg01).
    # Listing it here for documentation; the generator skips it.
    poeInPort = "ether1";

    ports = {
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
