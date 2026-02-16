{
  config,
  lib,
  ...
}: let
  vlanIds = [
    10 # main network

    20 # lab
    21
    22
    23

    240 # mgmt
    250 # transit
  ];
  vlanIface = iface: id: "${iface}.${builtins.toString id}";
  vlanNetdev = iface: id: {
    netdevConfig = {
      Name = vlanIface iface id;
      Kind = "vlan";
    };
    vlanConfig.Id = id;
  };
  vlanNetdevPair = iface: id:
    lib.nameValuePair
    "31-${vlanIface iface id}"
    (vlanNetdev iface id);

  dhcpVlans = [10 20 21 22 23 240];

  labServers = [
    {
      name = "lab-1";
      n = 1;
      interfaces = {
        mgmt = "94:18:82:74:f4:e0";
        eno1 = "94:18:82:79:b9:f0";
        eno2 = "94:18:82:79:b9:f1";
        eno3 = "94:18:82:79:b9:f2";
        eno4 = "94:18:82:79:b9:f3";
      };
    }
    {
      name = "lab-2";
      n = 2;
      interfaces = {
        mgmt = "94:18:82:85:00:82";
        eno1 = "94:18:82:89:83:70";
        eno2 = "94:18:82:89:83:71";
        eno3 = "94:18:82:89:83:72";
        eno4 = "94:18:82:89:83:73";
      };
    }
    {
      name = "lab-3";
      n = 3;
      interfaces = {
        mgmt = "14:02:EC:37:A1:48";
        eno1 = "14:02:ec:35:02:a4";
        eno2 = "14:02:ec:35:02:a5";
        eno3 = "14:02:ec:35:02:a6";
        eno4 = "14:02:ec:35:02:a7";
      };
    }
    {
      name = "lab-4";
      n = 4;
      interfaces = {
        mgmt = "94:57:a5:51:20:62";
        eno1 = "14:02:ec:33:97:a0";
        eno2 = "14:02:ec:33:97:a1";
        eno3 = "14:02:ec:33:97:a2";
        eno4 = "14:02:ec:33:97:a3";
      };
    }
  ];

  vlanIfaceMap = {
    "10" = null;
    "20" = "eno1";
    "21" = "eno2";
    "22" = "eno3";
    "23" = "eno4";
    "240" = "mgmt";
  };

  mkSubnet = vlanId: let
    prefix = "10.0.${toString vlanId}";
    ifaceName = vlanIfaceMap.${toString vlanId} or null;
  in {
    id = vlanId;
    subnet = "${prefix}.0/24";
    pools = [{pool = "${prefix}.100 - ${prefix}.199";}];
    "option-data" = [
      {
        name = "routers";
        data = "${prefix}.1";
      }
      {
        name = "domain-name-servers";
        data = "${prefix}.1";
      }
    ];
    reservations =
      if ifaceName == null
      then []
      else
        map (s: {
          "hw-address" = s.interfaces.${ifaceName};
          "ip-address" = "${prefix}.${toString (10 + s.n)}";
          hostname = s.name;
        })
        labServers;
  };
in {
  config = lib.mkIf (config.psyclyx.nixos.host == "iyr") {
    networking.firewall = {
      enable = false;
      allowedUDPPorts = [67 53];
      allowedTCPPorts = [53];
    };

    networking.nat = {
      enable = true;
      externalInterface = "bond0.250";
      internalInterfaces = map (id: "bond0.${toString id}") [10 20 21 22 23 240];
    };

    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

    psyclyx.nixos.services.kea = {
      enable = true;
      interfaces = map (id: "bond0.${toString id}") dhcpVlans;
      subnets = map mkSubnet dhcpVlans;
    };

    systemd.network = {
      netdevs =
        {
          "30-bond0" = {
            netdevConfig = {
              Name = "bond0";
              Kind = "bond";
            };
            bondConfig = {
              Mode = "802.3ad";
              LACPTransmitRate = "fast";
              TransmitHashPolicy = "layer3+4";
              MIIMonitorSec = "1s";
            };
          };
        }
        // (builtins.listToAttrs (map (vlanNetdevPair "bond0") vlanIds));

      networks = let
        vlanUnit = id: "31-bond0.${builtins.toString id}";
        vlan = id: {
          matchConfig.Name = vlanIface "bond0" id;
          address = ["10.0.${toString id}.1/24"];
          linkConfig.RequiredForOnline = "no";
        };
      in {
        "30-bond0-ports" = {
          matchConfig.Name = "enp1s0 enp3s0";
          networkConfig.Bond = "bond0";
        };

        "30-bond0" = {
          matchConfig.Name = "bond0";
          linkConfig.RequiredForOnline = "carrier";

          networkConfig = {
            Domains = ["~." "~psyclyx.xyz"];
            DHCP = "no";
          };

          address = ["10.0.0.11/24"];
          dns = ["127.0.0.1"];

          vlan = map (vlanIface "bond0") vlanIds;
        };

        "${vlanUnit 10}" = vlan 10;
        "${vlanUnit 20}" = vlan 20;
        "${vlanUnit 21}" = vlan 21;
        "${vlanUnit 22}" = vlan 22;
        "${vlanUnit 23}" = vlan 23;
        "${vlanUnit 240}" = vlan 240;
        "${vlanUnit 250}" = {
          matchConfig.Name = vlanIface "bond0" 250;
          networkConfig.DHCP = "ipv4";
          dhcpV4Config.UseRoutes = true;
          linkConfig.RequiredForOnline = "no";
        };
      };
    };
  };
}
