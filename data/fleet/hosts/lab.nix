{
  "lab-1" = {
    mac = {
      mgmt = "94:18:82:74:f4:e0";
      eno1 = "94:18:82:79:b9:f0";
      eno2 = "94:18:82:79:b9:f1";
      eno3 = "94:18:82:79:b9:f2";
      eno4 = "94:18:82:79:b9:f3";
    };
    interfaces = {
      rack = { bond = "bond0"; members = ["eno1" "eno2"]; };
      data = { device = "eno3"; };
      mgmt = { device = "mgmt"; };
    };
    addresses = {
      rack = { ipv4 = "10.157.10.11"; ipv6 = "fd9a:e830:4b1e:14::b"; };
      data = { ipv4 = "10.0.30.11"; ipv6 = "fd9a:e830:4b1e:1e::b"; };
      mgmt = { ipv4 = "10.0.240.11"; ipv6 = "fd9a:e830:4b1e:f0::b"; };
    };
    roles = ["server" "lab"];
    services = {
      node = { port = 9100; networks = ["rack"]; };
      smartctl = { port = 9633; networks = ["rack"]; };
      redis = { port = 9121; networks = ["rack"]; };
      postgres = { port = 9187; networks = ["rack"]; };
      seaweedfs-master = { port = 9327; networks = ["rack"]; };
      seaweedfs-volume = { port = 9328; networks = ["rack"]; };
      seaweedfs-filer = { port = 9329; networks = ["rack"]; };
      seaweedfs-s3 = { port = 9330; networks = ["rack"]; };
      haproxy = { port = 9101; networks = ["rack"]; };
      attic = { port = 9199; networks = ["rack"]; };
      etcd = { port = 2379; networks = ["rack"]; };
      patroni = { port = 8008; networks = ["rack"]; };
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
      rack = { bond = "bond0"; members = ["eno1" "eno2"]; };
      data = { device = "eno3"; };
      mgmt = { device = "mgmt"; };
    };
    addresses = {
      rack = { ipv4 = "10.157.10.12"; ipv6 = "fd9a:e830:4b1e:14::c"; };
      data = { ipv4 = "10.0.30.12"; ipv6 = "fd9a:e830:4b1e:1e::c"; };
      mgmt = { ipv4 = "10.0.240.12"; ipv6 = "fd9a:e830:4b1e:f0::c"; };
    };
    roles = ["server" "lab"];
    services = {
      node = { port = 9100; networks = ["rack"]; };
      smartctl = { port = 9633; networks = ["rack"]; };
      redis = { port = 9121; networks = ["rack"]; };
      postgres = { port = 9187; networks = ["rack"]; };
      seaweedfs-master = { port = 9327; networks = ["rack"]; };
      seaweedfs-volume = { port = 9328; networks = ["rack"]; };
      seaweedfs-filer = { port = 9329; networks = ["rack"]; };
      seaweedfs-s3 = { port = 9330; networks = ["rack"]; };
      haproxy = { port = 9101; networks = ["rack"]; };
      attic = { port = 9199; networks = ["rack"]; };
      etcd = { port = 2379; networks = ["rack"]; };
      patroni = { port = 8008; networks = ["rack"]; };
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
      rack = { bond = "bond0"; members = ["eno1" "eno2"]; };
      data = { device = "eno3"; };
      mgmt = { device = "mgmt"; };
    };
    addresses = {
      rack = { ipv4 = "10.157.10.13"; ipv6 = "fd9a:e830:4b1e:14::d"; };
      data = { ipv4 = "10.0.30.13"; ipv6 = "fd9a:e830:4b1e:1e::d"; };
      mgmt = { ipv4 = "10.0.240.13"; ipv6 = "fd9a:e830:4b1e:f0::d"; };
    };
    roles = ["server" "lab"];
    services = {
      node = { port = 9100; networks = ["rack"]; };
      smartctl = { port = 9633; networks = ["rack"]; };
      redis = { port = 9121; networks = ["rack"]; };
      postgres = { port = 9187; networks = ["rack"]; };
      seaweedfs-master = { port = 9327; networks = ["rack"]; };
      seaweedfs-volume = { port = 9328; networks = ["rack"]; };
      seaweedfs-filer = { port = 9329; networks = ["rack"]; };
      seaweedfs-s3 = { port = 9330; networks = ["rack"]; };
      haproxy = { port = 9101; networks = ["rack"]; };
      attic = { port = 9199; networks = ["rack"]; };
      etcd = { port = 2379; networks = ["rack"]; };
      patroni = { port = 8008; networks = ["rack"]; };
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
      rack = { bond = "bond0"; members = ["eno1" "eno2"]; };
      data = { device = "eno3"; };
      mgmt = { device = "mgmt"; };
    };
    addresses = {
      rack = { ipv4 = "10.157.10.14"; ipv6 = "fd9a:e830:4b1e:14::e"; };
      data = { ipv4 = "10.0.30.14"; ipv6 = "fd9a:e830:4b1e:1e::e"; };
      mgmt = { ipv4 = "10.0.240.14"; ipv6 = "fd9a:e830:4b1e:f0::e"; };
    };
    roles = ["server" "lab"];
    services = {
      node = { port = 9100; networks = ["rack"]; };
      smartctl = { port = 9633; networks = ["rack"]; };
      redis = { port = 9121; networks = ["rack"]; };
      postgres = { port = 9187; networks = ["rack"]; };
      seaweedfs-volume = { port = 9328; networks = ["rack"]; };
      seaweedfs-filer = { port = 9329; networks = ["rack"]; };
      seaweedfs-s3 = { port = 9330; networks = ["rack"]; };
      haproxy = { port = 9101; networks = ["rack"]; };
      attic = { port = 9199; networks = ["rack"]; };
      etcd = { port = 2379; networks = ["rack"]; };
      patroni = { port = 8008; networks = ["rack"]; };
    };
  };
}
