# Lab hosts — DL360 Gen9 servers in the apartment rack.
#
# mkLabHost reduces boilerplate: each lab host shares interfaces,
# address scheme, roles, tags, and exporter sets.
let
  lib = import <nixpkgs/lib>;

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

  mkLabHost = { n, mgmtMac, eno1Mac, eno2Mac, eno3Mac, eno4Mac, sfpDataMac, sfpProdMac, sfpDataDev, sfpProdDev, wgKey, exporters }: {
    type = "host";
    tags = ["server" "lab" "apartment" "fixed"];
    refs.bmc = "lab-${toString n}-ilo";
    host = {
      site = "apt";
      mac = {
        mgmt = mgmtMac;
        eno1 = eno1Mac;
        eno2 = eno2Mac;
        eno3 = eno3Mac;
        eno4 = eno4Mac;
        ${sfpDataDev} = sfpDataMac;
        ${sfpProdDev} = sfpProdMac;
      };
      interfaces = {
        main  = { device = "bond0.10"; };
        infra = { device = "bond0.25"; };
        stage = { device = "bond0.31"; };
        prod  = { device = sfpProdDev; };
        data  = { device = sfpDataDev; };
      };
      addresses = {
        vpn   = { ipv4 = "10.157.0.${toString (10 + n)}"; };
        main  = { ipv4 = "10.0.10.${toString (10 + n)}";  ipv6 = "fd9a:e830:4b1e:a::${lib.toHexString (10 + n)}"; };
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
      deployAddress = "10.0.25.${toString (10 + n)}";
      inherit exporters;
    };
  };
in {
  gate = "always";
  config = {
    entities = {
      lab-1 = mkLabHost {
        n = 1;
        mgmtMac = "94:18:82:74:f4:e0";
        eno1Mac = "94:18:82:79:b9:f0";
        eno2Mac = "94:18:82:79:b9:f1";
        eno3Mac = "94:18:82:79:b9:f2";
        eno4Mac = "94:18:82:79:b9:f3";
        sfpDataMac = "98:f2:b3:d7:58:c1";  # eno50np1 → CRS326 sfp-sfpplus1
        sfpProdMac = "98:f2:b3:d7:58:c0";  # eno49np0 → CRS326 sfp-sfpplus2
        sfpDataDev = "eno50np1";
        sfpProdDev = "eno49np0";
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
        sfpDataMac = "14:02:ec:90:67:19";  # ens1f1 → CRS326 sfp-sfpplus3
        sfpProdMac = "14:02:ec:90:67:18";  # ens1f0 → CRS326 sfp-sfpplus4
        sfpDataDev = "ens1f1";
        sfpProdDev = "ens1f0";
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
        sfpDataMac = "14:02:ec:44:29:dc";  # eno50 → CRS326 sfp-sfpplus5
        sfpProdMac = "14:02:ec:44:29:d8";  # eno49 → CRS326 sfp-sfpplus6
        sfpDataDev = "eno50";
        sfpProdDev = "eno49";
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
        sfpDataMac = "98:f2:b3:d7:b9:d1";  # eno50np1 → CRS326 sfp-sfpplus7
        sfpProdMac = "98:f2:b3:d7:b9:d0";  # eno49np0 → CRS326 sfp-sfpplus8
        sfpDataDev = "eno50np1";
        sfpProdDev = "eno49np0";
        wgKey   = "DpCTkovVZTGzRzjPFJg6ZTnFVN05mugTb94v+UgfclA=";
        exporters = labExporters;
      };
    };
  };
}
