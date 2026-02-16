{
  config,
  lib,
  ...
}: let
  vlanIds = [
    10 # vpn
    11
    12
    13
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

  dhcpVlans = [10 11 12 13];

  labServers = [
    {
      name = "lab-1";
      n = 1;
      macs = [
        "94:18:82:79:b9:f0" # eno1 → vlan 10
        "94:18:82:79:b9:f1" # eno2 → vlan 11
        "94:18:82:79:b9:f2" # eno3 → vlan 12
        "94:18:82:79:b9:f3" # eno4 → vlan 13
      ];
    }
    {
      name = "lab-2";
      n = 2;
      macs = [
        "94:18:82:89:83:70"
        "94:18:82:89:83:71"
        "94:18:82:89:83:72"
        "94:18:82:89:83:73"
      ];
    }
    {
      name = "lab-3";
      n = 3;
      macs = [
        "14:02:ec:35:02:a4"
        "14:02:ec:35:02:a5"
        "14:02:ec:35:02:a6"
        "14:02:ec:35:02:a7"
      ];
    }
    {
      name = "lab-4";
      n = 4;
      macs = [
        "14:02:ec:33:97:a0"
        "14:02:ec:33:97:a1"
        "14:02:ec:33:97:a2"
        "14:02:ec:33:97:a3"
      ];
    }
  ];

  mkSubnet = vlanId: let
    macIndex = vlanId - 10;
    prefix = "10.0.${toString vlanId}";
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
        data = "10.0.0.10";
      }
    ];
    reservations =
      map (s: {
        "hw-address" = builtins.elemAt s.macs macIndex;
        "ip-address" = "${prefix}.${toString (10 + s.n)}";
        hostname = s.name;
      })
      labServers;
  };
in {
  config = lib.mkIf (config.psyclyx.nixos.host == "iyr") {
    networking.firewall.allowedUDPPorts = [67];
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
          gateway = ["10.0.0.10"];
          dns = ["10.0.0.10"];

          vlan = map (vlanIface "bond0") vlanIds;
        };

        "${vlanUnit 10}" = vlan 10;
        "${vlanUnit 11}" = vlan 11;
        "${vlanUnit 12}" = vlan 12;
        "${vlanUnit 13}" = vlan 13;
        "${vlanUnit 240}" = vlan 240;
        "${vlanUnit 250}" = vlan 250;
      };
    };
  };
}
