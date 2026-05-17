# Lab hosts — DL360 Gen9 servers in the apartment rack.
#
# After the 2026 storage-host rework, lab hosts speak only over their two
# 10G NICs: one on the storage VLAN (iSCSI), one on the lab VLAN
# (everything else). iLO BMC stays on the mgmt VLAN. The 1G bond was
# retired.
#
# mkLabHost compresses the per-host boilerplate. Each host declares the
# physical NIC identifiers and MAC addresses; addresses fall out by host
# index n.
let
  lib = import <nixpkgs/lib>;

  mkLabHost =
    {
      n,
      mgmtMac,
      storageMac,
      labMac,
      storageDev,
      labDev,
      wgKey,
    }:
    {
      type = "host";
      tags = [
        "server"
        "lab"
        "apartment"
        "fixed"
      ];
      refs.bmc = "lab-${toString n}-ilo";
      host = {
        site = "apt";
        mac = {
          mgmt = mgmtMac;
          ${storageDev} = storageMac;
          ${labDev} = labMac;
        };
        interfaces = {
          storage = { device = storageDev; };
          lab     = { device = labDev; };
        };
        addresses = {
          vpn = {
            ipv4 = "10.157.0.${toString (10 + n)}";
          };
          storage = {
            ipv4 = "10.0.200.${toString (10 + n)}";
            ipv6 = "fd9a:e830:4b1e:c8::${lib.toHexString (10 + n)}";
          };
          lab = {
            ipv4 = "10.0.210.${toString (10 + n)}";
            ipv6 = "fd9a:e830:4b1e:d2::${lib.toHexString (10 + n)}";
          };
        };
        # All lab hosts PXE-boot from iyr over the lab VLAN. Firmware
        # boot order must select the labDev NIC; the PXE projection
        # uses host.mac.<labDev> for per-MAC reservations.
        boot = {
          mode = "pxe";
          pxeInterface = "lab";
        };
        wireguard = {
          publicKey = wgKey;
          allowedNetworks = [ ];
        };
        roles = [
          "server"
          "lab"
        ];
        # Reach lab hosts on the lab VLAN. Other apartment hosts route to
        # 10.0.210.0/24 via mdf-agg01 (hardware-offloaded).
        deployAddress = "10.0.210.${toString (10 + n)}";
      };
    };
in
{
  gate = "always";
  config = {
    entities = {
      lab-1 = mkLabHost {
        n = 1;
        mgmtMac    = "94:18:82:74:f4:e0";
        # eno50np1 was sfpDataDev — now the storage NIC.
        storageMac = "98:f2:b3:d7:58:c1";
        storageDev = "eno50np1";
        # eno49np0 was sfpProdDev — now the lab NIC.
        labMac     = "98:f2:b3:d7:58:c0";
        labDev     = "eno49np0";
        wgKey = "gLXnmGgfyhDIvlFeHaoY3ZzbOArm3zW0HUqI8JtF3R8=";
      };

      lab-2 = mkLabHost {
        n = 2;
        mgmtMac    = "94:18:82:85:00:82";
        storageMac = "14:02:ec:90:67:19";   # ens1f1
        storageDev = "ens1f1";
        labMac     = "14:02:ec:90:67:18";   # ens1f0
        labDev     = "ens1f0";
        wgKey = "0EjNTYFGhcUgKr/xQ5iW3vN95mm4GwOv9iO5jGxX+xg=";
      };

      lab-3 = mkLabHost {
        n = 3;
        mgmtMac    = "14:02:EC:37:A1:48";
        storageMac = "14:02:ec:44:29:dc";   # eno50
        storageDev = "eno50";
        labMac     = "14:02:ec:44:29:d8";   # eno49
        labDev     = "eno49";
        wgKey = "vel9qfECtCSjJxzsMhdzVDgEyNzT7sIEqQ3T1pIiNT0=";
      };

      lab-4 = mkLabHost {
        n = 4;
        mgmtMac    = "94:57:a5:51:20:62";
        storageMac = "98:f2:b3:d7:b9:d1";   # eno50np1
        storageDev = "eno50np1";
        labMac     = "98:f2:b3:d7:b9:d0";   # eno49np0
        labDev     = "eno49np0";
        wgKey = "DpCTkovVZTGzRzjPFJg6ZTnFVN05mugTb94v+UgfclA=";
        # lab-4 owns the pool — no boot LUN.
      };
    };
  };
}
