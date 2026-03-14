# Switch port assignments — the physical cabling reality.
#
# Each port maps to either:
#   { host; interface; }  — an access port for a host NIC
#   { type = "trunk"; peer; vlans; }  — a tagged trunk to another switch or router
#   { type = "unused"; }  — explicitly unassigned
#
# The network (VLAN) for access ports is derived from the host's interface
# mapping in hosts/*.nix — the switch data says WHICH port, the host data
# says WHICH VLAN.  The generator joins them.
{
  crs326 = {
    model = "CRS326-24S+2Q+RM";
    platform = "routeros";
    description = "10G SFP+ aggregation switch";
    # Management address on mgmt VLAN
    addresses.mgmt.ipv4 = "10.0.240.2";

    ports = {
      # Lab host 10G NICs — 2 per host (data + prod)
      # Port names match RouterOS SFP+ naming
      "sfp-sfpplus1"  = { host = "lab-1"; interface = "data"; };
      "sfp-sfpplus2"  = { host = "lab-1"; interface = "prod"; };
      "sfp-sfpplus3"  = { host = "lab-2"; interface = "data"; };
      "sfp-sfpplus4"  = { host = "lab-2"; interface = "prod"; };
      "sfp-sfpplus5"  = { host = "lab-3"; interface = "data"; };
      "sfp-sfpplus6"  = { host = "lab-3"; interface = "prod"; };
      "sfp-sfpplus7"  = { host = "lab-4"; interface = "data"; };
      "sfp-sfpplus8"  = { host = "lab-4"; interface = "prod"; };

      # Trunk to CSS326
      "sfp-sfpplus9"  = { type = "trunk"; peer = "css326"; vlans = "all"; };

      # Unused ports
      "sfp-sfpplus10" = { type = "unused"; };
      "sfp-sfpplus11" = { type = "unused"; };
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

  css326 = {
    model = "CSS326-24G-2S+RM";
    platform = "swos";
    description = "1G access switch";
    # Management address on mgmt VLAN
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
      ether13 = { type = "trunk"; peer = "iyr"; vlans = "all"; };

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
      "sfp-sfpplus1" = { type = "trunk"; peer = "crs326"; vlans = "all"; };
      "sfp-sfpplus2" = { type = "unused"; };
    };
  };
}
