{
  config,
  lib,
  ...
}: let
  vlanIds = [
    10
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
in {
  config = lib.mkIf (config.psyclyx.nixos.host == "iyr") {
    networking.firewall.allowedUDPPorts = [67];

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
        vlan = id: {dhcp ? false}:
          {
            matchConfig.Name = vlanIface "bond0" id;
            address = ["10.0.${toString id}.1/24"];
            linkConfig.RequiredForOnline = "no";
          }
          // lib.optionalAttrs dhcp {
            networkConfig.DHCPServer = true;
            dhcpServerConfig = {
              PoolOffset = 100;
              PoolSize = 100;
              DNS = ["10.0.0.10"];
              DefaultLeaseTimeSec = 3600;
            };
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
            Domains = ["~."];
            DHCP = "no";
          };

          address = ["10.0.0.11/24"];
          gateway = ["10.0.0.10"];
          dns = ["10.0.0.10"];

          vlan = map (vlanIface "bond0") vlanIds;
        };

        "${vlanUnit 10}" = vlan 10 {dhcp = true;};
        "${vlanUnit 11}" = vlan 11 {dhcp = true;};
        "${vlanUnit 12}" = vlan 12 {dhcp = true;};
        "${vlanUnit 13}" = vlan 13 {dhcp = true;};
        "${vlanUnit 240}" = vlan 240 {};
        "${vlanUnit 250}" = vlan 250 {};
      };
    };
  };
}
