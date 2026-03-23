let
  labServices = {
    node = {
      port = 9100;
      networks = ["vpn"];
    };
    smartctl = {
      port = 9633;
      networks = ["vpn"];
    };
    redis = {
      port = 9121;
      networks = ["infra"];
    };
    postgres = {
      port = 9187;
      networks = ["infra"];
    };
    seaweedfs-volume = {
      port = 9328;
      networks = ["infra"];
    };
    seaweedfs-filer = {
      port = 9329;
      networks = ["infra"];
    };
    seaweedfs-s3 = {
      port = 9330;
      networks = ["infra"];
    };
    haproxy = {
      port = 9101;
      networks = ["infra"];
    };
    etcd = {
      port = 2379;
      networks = ["infra"];
    };
    patroni = {
      port = 8008;
      networks = ["infra"];
    };
    openbao = {
      port = 8200;
      networks = ["infra"];
    };
    consul = {
      port = 8500;
      networks = ["infra"];
    };
    nomad = {
      port = 4646;
      networks = ["infra"];
    };
  };

  labMasterServices =
    labServices
    // {
      seaweedfs-master = {
        port = 9327;
        networks = ["infra"];
      };
    };

  labInterfaces = {
    infra = {device = "eno1";};
    stage = {device = "eno2";};
    prod = {device = "eno3";};
    mgmt = {device = "mgmt";};
  };

  labRoles = ["server" "lab"];
in {
  "lab-1" = {
    mac = {
      mgmt = "94:18:82:74:f4:e0";
      eno1 = "94:18:82:79:b9:f0";
      eno2 = "94:18:82:79:b9:f1";
      eno3 = "94:18:82:79:b9:f2";
      eno4 = "94:18:82:79:b9:f3";
    };
    interfaces = labInterfaces;
    wireguard.publicKey = "gLXnmGgfyhDIvlFeHaoY3ZzbOArm3zW0HUqI8JtF3R8=";
    addresses = {
      vpn = {ipv4 = "10.157.0.11";};
      infra = {
        ipv4 = "10.0.25.11";
        ipv6 = "fd9a:e830:4b1e:19::b";
      };
      prod = {
        ipv4 = "10.0.30.11";
        ipv6 = "fd9a:e830:4b1e:1e::b";
      };
      stage = {
        ipv4 = "10.0.31.11";
        ipv6 = "fd9a:e830:4b1e:1f::b";
      };
      data = {
        ipv4 = "10.0.50.11";
        ipv6 = "fd9a:e830:4b1e:32::b";
      };
      mgmt = {
        ipv4 = "10.0.240.11";
        ipv6 = "fd9a:e830:4b1e:f0::b";
      };
    };
    roles = labRoles;
    services = labMasterServices;
  };

  "lab-2" = {
    mac = {
      mgmt = "94:18:82:85:00:82";
      eno1 = "94:18:82:89:83:70";
      eno2 = "94:18:82:89:83:71";
      eno3 = "94:18:82:89:83:72";
      eno4 = "94:18:82:89:83:73";
    };
    interfaces = labInterfaces;
    wireguard.publicKey = "0EjNTYFGhcUgKr/xQ5iW3vN95mm4GwOv9iO5jGxX+xg=";
    addresses = {
      vpn = {ipv4 = "10.157.0.12";};
      infra = {
        ipv4 = "10.0.25.12";
        ipv6 = "fd9a:e830:4b1e:19::c";
      };
      prod = {
        ipv4 = "10.0.30.12";
        ipv6 = "fd9a:e830:4b1e:1e::c";
      };
      stage = {
        ipv4 = "10.0.31.12";
        ipv6 = "fd9a:e830:4b1e:1f::c";
      };
      data = {
        ipv4 = "10.0.50.12";
        ipv6 = "fd9a:e830:4b1e:32::c";
      };
      mgmt = {
        ipv4 = "10.0.240.12";
        ipv6 = "fd9a:e830:4b1e:f0::c";
      };
    };
    roles = labRoles;
    services = labMasterServices;
  };

  "lab-3" = {
    mac = {
      mgmt = "14:02:EC:37:A1:48";
      eno1 = "14:02:ec:35:02:a4";
      eno2 = "14:02:ec:35:02:a5";
      eno3 = "14:02:ec:35:02:a6";
      eno4 = "14:02:ec:35:02:a7";
    };
    interfaces = labInterfaces;
    wireguard.publicKey = "vel9qfECtCSjJxzsMhdzVDgEyNzT7sIEqQ3T1pIiNT0=";
    addresses = {
      vpn = {ipv4 = "10.157.0.13";};
      infra = {
        ipv4 = "10.0.25.13";
        ipv6 = "fd9a:e830:4b1e:19::d";
      };
      prod = {
        ipv4 = "10.0.30.13";
        ipv6 = "fd9a:e830:4b1e:1e::d";
      };
      stage = {
        ipv4 = "10.0.31.13";
        ipv6 = "fd9a:e830:4b1e:1f::d";
      };
      data = {
        ipv4 = "10.0.50.13";
        ipv6 = "fd9a:e830:4b1e:32::d";
      };
      mgmt = {
        ipv4 = "10.0.240.13";
        ipv6 = "fd9a:e830:4b1e:f0::d";
      };
    };
    roles = labRoles;
    services = labMasterServices;
  };

  "lab-4" = {
    mac = {
      mgmt = "94:57:a5:51:20:62";
      eno1 = "14:02:ec:33:97:a0";
      eno2 = "14:02:ec:33:97:a1";
      eno3 = "14:02:ec:33:97:a2";
      eno4 = "14:02:ec:33:97:a3";
    };
    interfaces = labInterfaces;
    wireguard.publicKey = "DpCTkovVZTGzRzjPFJg6ZTnFVN05mugTb94v+UgfclA=";
    addresses = {
      vpn = {ipv4 = "10.157.0.14";};
      infra = {
        ipv4 = "10.0.25.14";
        ipv6 = "fd9a:e830:4b1e:19::e";
      };
      prod = {
        ipv4 = "10.0.30.14";
        ipv6 = "fd9a:e830:4b1e:1e::e";
      };
      stage = {
        ipv4 = "10.0.31.14";
        ipv6 = "fd9a:e830:4b1e:1f::e";
      };
      data = {
        ipv4 = "10.0.50.14";
        ipv6 = "fd9a:e830:4b1e:32::e";
      };
      mgmt = {
        ipv4 = "10.0.240.14";
        ipv6 = "fd9a:e830:4b1e:f0::e";
      };
    };
    roles = labRoles;
    services = labServices;
  };
}
