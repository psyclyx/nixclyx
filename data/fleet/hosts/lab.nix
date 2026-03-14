{
  "lab-1" = {
    mac = {
      mgmt = "94:18:82:74:f4:e0";
      eno1 = "94:18:82:79:b9:f0";
      eno2 = "94:18:82:79:b9:f1";
      eno3 = "94:18:82:79:b9:f2";
      eno4 = "94:18:82:79:b9:f3";
      # 10G NIC MACs: add after physical install
    };
    # Dedicated NIC per VLAN — no trunking on lab hosts.
    # 10G interfaces (data, prod) added after NIC install.
    interfaces = {
      infra = { device = "eno1"; };
      stage = { device = "eno2"; };
      mgmt  = { device = "mgmt"; }; # iLO BMC, not host OS
    };
    wireguard.publicKey = "m3+/5V8kpoSqIqFXPe1LGF0RXwdfXPfljhJctkGeOhg=";
    addresses = {
      vpn   = { ipv4 = "10.157.0.11"; };
      infra = { ipv4 = "10.0.25.11"; ipv6 = "fd9a:e830:4b1e:19::b"; };
      prod  = { ipv4 = "10.0.30.11"; ipv6 = "fd9a:e830:4b1e:1e::b"; };
      stage = { ipv4 = "10.0.31.11"; ipv6 = "fd9a:e830:4b1e:1f::b"; };
      data  = { ipv4 = "10.0.50.11"; ipv6 = "fd9a:e830:4b1e:32::b"; };
      mgmt  = { ipv4 = "10.0.240.11"; ipv6 = "fd9a:e830:4b1e:f0::b"; };
    };
    roles = ["server" "lab"];
    services = {
      node     = { port = 9100; networks = ["vpn"]; };
      smartctl = { port = 9633; networks = ["vpn"]; };
      redis              = { port = 9121; networks = ["data"]; };
      postgres           = { port = 9187; networks = ["data"]; };
      seaweedfs-master   = { port = 9327; networks = ["data"]; };
      seaweedfs-volume   = { port = 9328; networks = ["data"]; };
      seaweedfs-filer    = { port = 9329; networks = ["data"]; };
      seaweedfs-s3       = { port = 9330; networks = ["data"]; };
      haproxy  = { port = 9101; networks = ["infra"]; };
      attic    = { port = 9199; networks = ["infra"]; };
      etcd     = { port = 2379; networks = ["data"]; };
      patroni  = { port = 8008; networks = ["infra"]; };
      openbao  = { port = 8200; networks = ["infra"]; };
    };
  };

  "lab-2" = {
    mac = {
      mgmt = "94:18:82:85:00:82";
      eno1 = "94:18:82:89:83:70";
      eno2 = "94:18:82:89:83:71";
      eno3 = "94:18:82:89:83:72";
      eno4 = "94:18:82:89:83:73";
    };
    interfaces = {
      infra = { device = "eno1"; };
      stage = { device = "eno2"; };
      mgmt  = { device = "mgmt"; };
    };
    wireguard.publicKey = "I+LxIxnWAnmf/tlotUNqnmcVVpRikL/hk9G5tlfDLHI=";
    addresses = {
      vpn   = { ipv4 = "10.157.0.12"; };
      infra = { ipv4 = "10.0.25.12"; ipv6 = "fd9a:e830:4b1e:19::c"; };
      prod  = { ipv4 = "10.0.30.12"; ipv6 = "fd9a:e830:4b1e:1e::c"; };
      stage = { ipv4 = "10.0.31.12"; ipv6 = "fd9a:e830:4b1e:1f::c"; };
      data  = { ipv4 = "10.0.50.12"; ipv6 = "fd9a:e830:4b1e:32::c"; };
      mgmt  = { ipv4 = "10.0.240.12"; ipv6 = "fd9a:e830:4b1e:f0::c"; };
    };
    roles = ["server" "lab"];
    services = {
      node     = { port = 9100; networks = ["vpn"]; };
      smartctl = { port = 9633; networks = ["vpn"]; };
      redis              = { port = 9121; networks = ["data"]; };
      postgres           = { port = 9187; networks = ["data"]; };
      seaweedfs-master   = { port = 9327; networks = ["data"]; };
      seaweedfs-volume   = { port = 9328; networks = ["data"]; };
      seaweedfs-filer    = { port = 9329; networks = ["data"]; };
      seaweedfs-s3       = { port = 9330; networks = ["data"]; };
      haproxy  = { port = 9101; networks = ["infra"]; };
      attic    = { port = 9199; networks = ["infra"]; };
      etcd     = { port = 2379; networks = ["data"]; };
      patroni  = { port = 8008; networks = ["infra"]; };
      openbao  = { port = 8200; networks = ["infra"]; };
    };
  };

  "lab-3" = {
    mac = {
      mgmt = "14:02:EC:37:A1:48";
      eno1 = "14:02:ec:35:02:a4";
      eno2 = "14:02:ec:35:02:a5";
      eno3 = "14:02:ec:35:02:a6";
      eno4 = "14:02:ec:35:02:a7";
    };
    interfaces = {
      infra = { device = "eno1"; };
      stage = { device = "eno2"; };
      mgmt  = { device = "mgmt"; };
    };
    wireguard.publicKey = "j8ezJkeoQZkpxxHwdogdhYoxQs1VqhvzCUar92r8mWY=";
    addresses = {
      vpn   = { ipv4 = "10.157.0.13"; };
      infra = { ipv4 = "10.0.25.13"; ipv6 = "fd9a:e830:4b1e:19::d"; };
      prod  = { ipv4 = "10.0.30.13"; ipv6 = "fd9a:e830:4b1e:1e::d"; };
      stage = { ipv4 = "10.0.31.13"; ipv6 = "fd9a:e830:4b1e:1f::d"; };
      data  = { ipv4 = "10.0.50.13"; ipv6 = "fd9a:e830:4b1e:32::d"; };
      mgmt  = { ipv4 = "10.0.240.13"; ipv6 = "fd9a:e830:4b1e:f0::d"; };
    };
    roles = ["server" "lab"];
    services = {
      node     = { port = 9100; networks = ["vpn"]; };
      smartctl = { port = 9633; networks = ["vpn"]; };
      redis              = { port = 9121; networks = ["data"]; };
      postgres           = { port = 9187; networks = ["data"]; };
      seaweedfs-master   = { port = 9327; networks = ["data"]; };
      seaweedfs-volume   = { port = 9328; networks = ["data"]; };
      seaweedfs-filer    = { port = 9329; networks = ["data"]; };
      seaweedfs-s3       = { port = 9330; networks = ["data"]; };
      haproxy  = { port = 9101; networks = ["infra"]; };
      attic    = { port = 9199; networks = ["infra"]; };
      etcd     = { port = 2379; networks = ["data"]; };
      patroni  = { port = 8008; networks = ["infra"]; };
      openbao  = { port = 8200; networks = ["infra"]; };
    };
  };

  "lab-4" = {
    mac = {
      mgmt = "94:57:a5:51:20:62";
      eno1 = "14:02:ec:33:97:a0";
      eno2 = "14:02:ec:33:97:a1";
      eno3 = "14:02:ec:33:97:a2";
      eno4 = "14:02:ec:33:97:a3";
    };
    interfaces = {
      infra = { device = "eno1"; };
      stage = { device = "eno2"; };
      mgmt  = { device = "mgmt"; };
    };
    wireguard.publicKey = "vBbdc+1SexiDWfao3x6f4AF2qISNKMBaQwTVFwHOwWg=";
    addresses = {
      vpn   = { ipv4 = "10.157.0.14"; };
      infra = { ipv4 = "10.0.25.14"; ipv6 = "fd9a:e830:4b1e:19::e"; };
      prod  = { ipv4 = "10.0.30.14"; ipv6 = "fd9a:e830:4b1e:1e::e"; };
      stage = { ipv4 = "10.0.31.14"; ipv6 = "fd9a:e830:4b1e:1f::e"; };
      data  = { ipv4 = "10.0.50.14"; ipv6 = "fd9a:e830:4b1e:32::e"; };
      mgmt  = { ipv4 = "10.0.240.14"; ipv6 = "fd9a:e830:4b1e:f0::e"; };
    };
    roles = ["server" "lab"];
    services = {
      node     = { port = 9100; networks = ["vpn"]; };
      smartctl = { port = 9633; networks = ["vpn"]; };
      redis              = { port = 9121; networks = ["data"]; };
      postgres           = { port = 9187; networks = ["data"]; };
      seaweedfs-volume   = { port = 9328; networks = ["data"]; };
      seaweedfs-filer    = { port = 9329; networks = ["data"]; };
      seaweedfs-s3       = { port = 9330; networks = ["data"]; };
      haproxy  = { port = 9101; networks = ["infra"]; };
      attic    = { port = 9199; networks = ["infra"]; };
      etcd     = { port = 2379; networks = ["data"]; };
      patroni  = { port = 8008; networks = ["infra"]; };
      openbao  = { port = 8200; networks = ["infra"]; };
    };
  };
}
