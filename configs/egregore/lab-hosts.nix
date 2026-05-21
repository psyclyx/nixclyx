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
      eno1Mac,
      storageMac,
      labMac,
      storageDev,
      labDev,
      wgKey,
      # Defaults to the loader for compute hosts; the storage host
      # (lab-4) overrides to true only after the lab-4 cutover is in
      # place. lab-1..3 don't have their own builds, so this is
      # effectively a no-op for them — but stay explicit.
      useLoader ? true,
    }:
    {
      type = "host";
      tags = [
        "server"
        "lab"
        "apartment"
        "fixed"
      ];
      refs = {
        bmc = "lab-${toString n}-ilo";
        # All lab hosts share the same /nix (NFS-exported from lab-4's
        # tank). Each has its own per-host /persist dataset; lab-4
        # mounts its locally, the others NFS-mount from lab-4.
        nixDataset = "tank-nix-shared";
        persistDataset = "tank-persist-lab-${toString n}";
      };
      host = {
        site = "apt";
        mac = {
          mgmt = mgmtMac;
          eno1 = eno1Mac;
          ${storageDev} = storageMac;
          ${labDev} = labMac;
        };
        # eno1 (1G, tg3) is the "for now" path — we don't have a kernel
        # module yet for the 10G NICs in netboot, so storage/lab stay
        # declared (for switch wiring + addressing once they come back)
        # but main is the default network and the PXE/deploy path.
        interfaces = {
          main    = { device = "eno1"; };
          storage = { device = storageDev; };
          lab     = { device = labDev; };
        };
        addresses = {
          vpn = {
            ipv4 = "10.157.0.${toString (10 + n)}";
          };
          # storage/lab addresses go via DHCP — Kea on iyr has per-MAC
          # reservations and the L3 path is direct via mdf-agg01. The
          # main interface stays static for now: DHCPDISCOVER broadcast
          # from lab-host eno1 doesn't reach iyr (suspected drop on
          # CSS326 → CRS326 → mdf-brk01 path; sigil's DHCP on the same
          # VLAN works fine because it bypasses CSS326). Revisit when
          # the broadcast issue is debugged.
          main = {
            ipv4 = "10.0.10.${toString (10 + n)}";
            ipv6 = "fd9a:e830:4b1e:a::${lib.toHexString (10 + n)}";
          };
          storage = {
            dhcp = true;
            ipv4 = "10.0.200.${toString (10 + n)}";
            ipv6 = "fd9a:e830:4b1e:c8::${lib.toHexString (10 + n)}";
          };
          lab = {
            dhcp = true;
            ipv4 = "10.0.210.${toString (10 + n)}";
            ipv6 = "fd9a:e830:4b1e:d2::${lib.toHexString (10 + n)}";
          };
        };
        # PXE-eligible on every interface with a DHCP pool (storage is
        # excluded — it's switch-routed L3 with no DHCP server). The
        # projection emits a per-MAC reservation in each named pool, so
        # firmware boot order can pick either eno1 (main) or the 10G
        # NIC (lab) and the chainload still works.
        boot = {
          mode = "pxe";
          pxeInterfaces = [ "main" "lab" ];
          inherit useLoader;
        };
        wireguard = {
          publicKey = wgKey;
          allowedNetworks = [ ];
        };
        roles = [
          "server"
          "lab"
        ];
        deployAddress = "10.0.10.${toString (10 + n)}";
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
        eno1Mac    = "94:18:82:79:b9:f0";
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
        eno1Mac    = "94:18:82:89:83:70";
        storageMac = "14:02:ec:90:67:19";   # ens1f1
        storageDev = "ens1f1";
        labMac     = "14:02:ec:90:67:18";   # ens1f0
        labDev     = "ens1f0";
        wgKey = "0EjNTYFGhcUgKr/xQ5iW3vN95mm4GwOv9iO5jGxX+xg=";
      };

      lab-3 = mkLabHost {
        n = 3;
        mgmtMac    = "14:02:EC:37:A1:48";
        eno1Mac    = "14:02:ec:35:02:a4";
        storageMac = "14:02:ec:44:29:dc";   # eno50
        storageDev = "eno50";
        labMac     = "14:02:ec:44:29:d8";   # eno49
        labDev     = "eno49";
        wgKey = "vel9qfECtCSjJxzsMhdzVDgEyNzT7sIEqQ3T1pIiNT0=";
      };

      lab-4 = mkLabHost {
        n = 4;
        mgmtMac    = "94:57:a5:51:20:62";
        eno1Mac    = "14:02:ec:33:97:a0";
        storageMac = "98:f2:b3:d7:b9:d1";   # eno50np1
        storageDev = "eno50np1";
        labMac     = "98:f2:b3:d7:b9:d0";   # eno49np0
        labDev     = "eno49np0";
        wgKey = "IjRhm1Lw0+nkD/Im+4QYAit3+JtlQ5FnvKShpY7+Tiw=";
        # lab-4 owns the pool — no boot LUN.
      };
    };
  };
}
