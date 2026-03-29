# Fleet data expressed as egregore entities.
#
# This is the single source of truth for the psyclyx fleet topology.
# All networks, hosts, switches, BMCs, and HA groups are declared here.
#
# Usage:
#   let
#     egregore = import ../../egregore { inherit lib; };
#     fleet = egregore.eval {
#       modules = [
#         ./egregore/extensions/globals.nix
#         ./egregore/types/network.nix
#         ./egregore/types/host.nix
#         ./egregore/types/routeros.nix
#         ./egregore/types/swos.nix
#         ./egregore/types/sodola.nix
#         ./egregore/types/ilo.nix
#         ./egregore/types/unmanaged.nix
#         ./egregore/types/ha-group.nix
#         ./data/egregore.nix
#       ];
#     };
#   in fleet.entities
#
let
  # Standard VLAN sets for switch port definitions.
  internal = [10 25 30 31 50 100 110 240];
  all      = internal ++ [250];

  # Shared lab host config.
  labExporters = {
    node             = { port = 9100; networks = ["vpn"]; };
    smartctl         = { port = 9633; networks = ["vpn"]; };
    redis            = { port = 9121; networks = ["infra"]; };
    postgres         = { port = 9187; networks = ["infra"]; };
    seaweedfs-volume = { port = 9328; networks = ["infra"]; };
    seaweedfs-filer  = { port = 9329; networks = ["infra"]; };
    seaweedfs-s3     = { port = 9330; networks = ["infra"]; };
    haproxy          = { port = 9101; networks = ["infra"]; };
    etcd             = { port = 2379; networks = ["infra"]; };
    patroni          = { port = 8008; networks = ["infra"]; };
    openbao          = { port = 8200; networks = ["infra"]; };
    k8s              = { port = 6443; networks = ["infra"]; };
  };

  labMasterExporters = labExporters // {
    seaweedfs-master = { port = 9327; networks = ["infra"]; };
  };

  labInterfaces = {
    infra = { device = "eno1"; };
    stage = { device = "eno2"; };
    prod  = { device = "eno3"; };
  };

  mkLabHost = { n, mgmtMac, eno1Mac, eno2Mac, eno3Mac, eno4Mac, wgKey, exporters }: {
    type = "host";
    tags = ["server" "lab" "apartment" "fixed"];
    refs.bmc = "lab-${toString n}-ilo";
    host = {
      mac = {
        mgmt = mgmtMac;
        eno1 = eno1Mac;
        eno2 = eno2Mac;
        eno3 = eno3Mac;
        eno4 = eno4Mac;
      };
      interfaces = labInterfaces;
      addresses = {
        vpn   = { ipv4 = "10.157.0.${toString (10 + n)}"; };
        infra = { ipv4 = "10.0.25.${toString (10 + n)}";  ipv6 = "fd9a:e830:4b1e:19::${lib.toHexString (10 + n)}"; };
        prod  = { ipv4 = "10.0.30.${toString (10 + n)}";  ipv6 = "fd9a:e830:4b1e:1e::${lib.toHexString (10 + n)}"; };
        stage = { ipv4 = "10.0.31.${toString (10 + n)}";  ipv6 = "fd9a:e830:4b1e:1f::${lib.toHexString (10 + n)}"; };
        data  = { ipv4 = "10.0.50.${toString (10 + n)}";  ipv6 = "fd9a:e830:4b1e:32::${lib.toHexString (10 + n)}"; };
      };
      wireguard = {
        publicKey = wgKey;
        allowedNetworks = [];
      };
      roles = ["server" "lab"];
      inherit exporters;
    };
  };

  lib = import <nixpkgs/lib>;
in {

  # ── Global configuration ──────────────────────────────────────────

  conventions = {
    gatewayOffset = 1;
    transitVlan = 250;
    adminSshKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPK+1GlLeOjyDZjcdGFXjDnJfgtO7OOOoeTliAwZRSsf psyc@sigil"
    ];
  };

  domains = {
    internal = "psyclyx.net";
    public   = "psyclyx.xyz";
    home     = "home.psyclyx.net";
  };

  ipv6UlaPrefix = "fd9a:e830:4b1e";

  overlay = {
    subnet = "10.157.0.0/24";
    port   = 51820;
    hub    = "tleilax";
  };

  # ── Entities ──────────────────────────────────────────────────────

  entities = {

    # ── Networks ──────────────────────────────────────────────────

    main  = { type = "network"; network = { vlan = 10;  ipv4 = "10.0.10.0/24";  ulaSubnetHex = "a";  ipv6PdSubnetId = 0; }; };
    infra = { type = "network"; network = { vlan = 25;  ipv4 = "10.0.25.0/24";  ulaSubnetHex = "19"; ipv6PdSubnetId = 1; }; };
    prod  = { type = "network"; network = { vlan = 30;  ipv4 = "10.0.30.0/24";  ulaSubnetHex = "1e"; ipv6PdSubnetId = 2; }; };
    stage = { type = "network"; network = { vlan = 31;  ipv4 = "10.0.31.0/24";  ulaSubnetHex = "1f"; ipv6PdSubnetId = 3; }; };
    data  = { type = "network"; network = { vlan = 50;  ipv4 = "10.0.50.0/24";  ulaSubnetHex = "32"; ipv6PdSubnetId = 4; }; };
    guest = { type = "network"; network = { vlan = 100; ipv4 = "10.0.100.0/24"; ulaSubnetHex = "64"; ipv6PdSubnetId = 5; }; };
    iot   = { type = "network"; network = { vlan = 110; ipv4 = "10.0.110.0/24"; ulaSubnetHex = "6e"; ipv6PdSubnetId = 6; }; };
    mgmt  = { type = "network"; network = { vlan = 240; ipv4 = "10.0.240.0/24"; ulaSubnetHex = "f0"; ipv6PdSubnetId = 7; }; };

    # ── Lab hosts ─────────────────────────────────────────────────

    lab-1 = mkLabHost {
      n = 1;
      mgmtMac = "94:18:82:74:f4:e0";
      eno1Mac = "94:18:82:79:b9:f0";
      eno2Mac = "94:18:82:79:b9:f1";
      eno3Mac = "94:18:82:79:b9:f2";
      eno4Mac = "94:18:82:79:b9:f3";
      wgKey   = "gLXnmGgfyhDIvlFeHaoY3ZzbOArm3zW0HUqI8JtF3R8=";
      exporters = labMasterExporters;
    };

    lab-2 = mkLabHost {
      n = 2;
      mgmtMac = "94:18:82:85:00:82";
      eno1Mac = "94:18:82:89:83:70";
      eno2Mac = "94:18:82:89:83:71";
      eno3Mac = "94:18:82:89:83:72";
      eno4Mac = "94:18:82:89:83:73";
      wgKey   = "0EjNTYFGhcUgKr/xQ5iW3vN95mm4GwOv9iO5jGxX+xg=";
      exporters = labMasterExporters;
    };

    lab-3 = mkLabHost {
      n = 3;
      mgmtMac = "14:02:EC:37:A1:48";
      eno1Mac = "14:02:ec:35:02:a4";
      eno2Mac = "14:02:ec:35:02:a5";
      eno3Mac = "14:02:ec:35:02:a6";
      eno4Mac = "14:02:ec:35:02:a7";
      wgKey   = "vel9qfECtCSjJxzsMhdzVDgEyNzT7sIEqQ3T1pIiNT0=";
      exporters = labMasterExporters;
    };

    lab-4 = mkLabHost {
      n = 4;
      mgmtMac = "94:57:a5:51:20:62";
      eno1Mac = "14:02:ec:33:97:a0";
      eno2Mac = "14:02:ec:33:97:a1";
      eno3Mac = "14:02:ec:33:97:a2";
      eno4Mac = "14:02:ec:33:97:a3";
      wgKey   = "DpCTkovVZTGzRzjPFJg6ZTnFVN05mugTb94v+UgfclA=";
      exporters = labExporters;
    };

    # ── Infrastructure hosts ──────────────────────────────────────

    tleilax = {
      type = "host";
      tags = ["server" "colo" "fixed"];
      host = {
        wireguard = {
          publicKey = "Hsytr+mjAfsBPoC99XHKLh9+jEbyz1REF0okmlviUVc=";
          endpoint  = "vpn.psyclyx.xyz:51820";
          allowedNetworks = ["main"];
        };
        addresses.vpn.ipv4 = "10.157.0.1";
        publicIPv4 = "199.255.18.171";
        publicIPv6 = "2606:7940:32:26::10";
        sshPort = 17891;
        roles = ["server" "vpn-hub"];
        exporters = {
          node     = { port = 9100; networks = ["vpn"]; };
          smartctl = { port = 9633; networks = ["vpn"]; };
        };
      };
    };

    iyr = {
      type = "host";
      tags = ["server" "apartment" "router" "fixed"];
      host = {
        wireguard = {
          publicKey = "9wnevbvkDGcyNnMECEzgfaghqi4tEw4GsgC/TUcSTS4=";
          exportedRoutes = [
            "10.0.10.0/24" "10.0.25.0/24" "10.0.30.0/24" "10.0.31.0/24"
            "10.0.50.0/24" "10.0.100.0/24" "10.0.110.0/24" "10.0.240.0/24"
          ];
        };
        addresses.vpn.ipv4 = "10.157.0.2";
        sshPort = 17891;
        roles = ["server" "router"];
        hardware.tpm = true;
        exporters = {
          node     = { port = 9100; networks = ["vpn"]; };
          smartctl = { port = 9633; networks = ["vpn"]; };
        };
      };
    };

    sigil = {
      type = "host";
      tags = ["workstation" "desktop" "apartment" "fixed"];
      host = {
        wireguard = {
          publicKey = "XKqqjC62uOUhbCn3JPpI0M6WFYqRf8sLpML90JZ1CmE=";
          allowedNetworks = ["main" "infra" "prod" "stage" "data" "mgmt"];
        };
        addresses.vpn.ipv4 = "10.157.0.3";
        roles = ["workstation"];
        hardware.tpm = true;
        exporters = {
          node     = { port = 9100; networks = ["vpn"]; };
          smartctl = { port = 9633; networks = ["vpn"]; };
        };
      };
    };

    phone = {
      type = "host";
      tags = ["mobile"];
      host = {
        wireguard = {
          publicKey = "SaYcJM6Fl1UhX1qzby9rjUJv+icRyh29jX+iIqFKdDw=";
          allowedNetworks = ["main" "infra"];
        };
        addresses.vpn.ipv4 = "10.157.0.4";
        roles = ["mobile"];
      };
    };

    omen = {
      type = "host";
      tags = ["workstation" "laptop"];
      host = {
        wireguard = {
          publicKey = "yTRNWKLNu6Xb+h7DcPPiWohWe0O6QSwJBlh5AjzChmU=";
          allowedNetworks = ["main" "infra"];
        };
        addresses.vpn.ipv4 = "10.157.0.5";
        roles = ["workstation"];
      };
    };

    glyph = {
      type = "host";
      tags = ["workstation" "laptop"];
      host = {
        wireguard = {
          publicKey = "7ufcd0IzKRR85YMIh0mfoxaG14uwW09c/h4AJaAC1xY=";
          allowedNetworks = ["main" "infra"];
        };
        addresses.vpn.ipv4 = "10.157.0.6";
        roles = ["workstation"];
      };
    };

    # ── iLO BMCs ──────────────────────────────────────────────────

    lab-1-ilo = {
      type = "ilo"; tags = ["bmc" "lab"];
      refs.host = "lab-1";
      ilo = { hostname = "lab-1-ilo.mgmt.home.psyclyx.net"; model = "DL360 Gen9"; };
    };

    lab-2-ilo = {
      type = "ilo"; tags = ["bmc" "lab"];
      refs.host = "lab-2";
      ilo = { hostname = "lab-2-ilo.mgmt.home.psyclyx.net"; model = "DL360 Gen9"; };
    };

    lab-3-ilo = {
      type = "ilo"; tags = ["bmc" "lab"];
      refs.host = "lab-3";
      ilo = { hostname = "lab-3-ilo.mgmt.home.psyclyx.net"; model = "DL360 Gen9"; };
    };

    lab-4-ilo = {
      type = "ilo"; tags = ["bmc" "lab"];
      refs.host = "lab-4";
      ilo = { hostname = "lab-4-ilo.mgmt.home.psyclyx.net"; model = "DL360 Gen9"; };
    };

    # ── Switches ──────────────────────────────────────────────────

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
          ether2  = { vlan = 25;  meta = { host = "lab-1"; description = "infra"; }; };
          ether3  = { vlan = 31;  meta = { host = "lab-1"; description = "stage"; }; };
          ether4  = { vlan = 30;  meta = { host = "lab-1"; description = "prod"; }; };
          ether5  = { vlan = 30;  meta = { host = "lab-1"; description = "eno4 (second prod link)"; }; };
          ether6  = { vlan = 240; meta = { host = "lab-2"; description = "BMC/iLO"; }; };
          ether7  = { vlan = 25;  meta = { host = "lab-2"; description = "infra"; }; };
          ether8  = { vlan = 31;  meta = { host = "lab-2"; description = "stage"; }; };
          ether9  = { vlan = 30;  meta = { host = "lab-2"; description = "prod"; }; };
          ether10 = { vlan = 30;  meta = { host = "lab-2"; description = "eno4 (second prod link)"; }; };
          ether11 = { vlan = 240; meta = { host = "lab-3"; description = "BMC/iLO"; }; };
          ether12 = { vlan = 25;  meta = { host = "lab-3"; description = "infra"; }; };
          ether13 = { vlan = 31;  meta = { host = "lab-3"; description = "stage"; }; };
          ether14 = { vlan = 30;  meta = { host = "lab-3"; description = "prod"; }; };
          ether15 = { vlan = 30;  meta = { host = "lab-3"; description = "eno4 (second prod link)"; }; };
          ether16 = { vlan = 240; meta = { host = "lab-4"; description = "BMC/iLO"; }; };
          ether17 = { vlan = 25;  meta = { host = "lab-4"; description = "infra"; }; };
          ether18 = { vlan = 31;  meta = { host = "lab-4"; description = "stage"; }; };
          ether19 = { vlan = 30;  meta = { host = "lab-4"; description = "prod"; }; };
          ether20 = { vlan = 30;  meta = { host = "lab-4"; description = "eno4 (second prod link)"; }; };
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

    # ── HA Groups ─────────────────────────────────────────────────

    lab = {
      type = "ha-group";
      ha-group = {
        network = "infra";
        vip = {
          ipv4 = "10.0.25.200";
          ipv6 = "fd9a:e830:4b1e:19::c8";
        };
        vrid = 200;
        members = ["lab-1" "lab-2" "lab-3" "lab-4"];
        services = {
          s3         = { port = 8333; check = "/status"; };
          webdav     = { port = 7333; };
          postgresql = { port = 5432; mode = "tcp"; check = "/primary"; checkPort = 8008; };
          openbao    = { port = 8200; check = "/v1/sys/health?standbyok=true"; };
          k8s-api    = { port = 6443; mode = "tcp"; check = "/readyz"; checkSsl = true; };
        };
      };
    };
  };
}
