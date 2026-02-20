{
  config,
  lib,
  nixclyx,
  ...
}: let
  topo = config.psyclyx.topology;
  dt = nixclyx.lib.topology lib topo;
  conventions = topo.conventions;

  thisHost = topo.hosts.iyr;

  natRules = lib.mapAttrsToList (netName: natPrefix: let
    realPrefix = topo.networks.${netName}.ipv4;
  in {
    inherit natPrefix realPrefix;
  }) (thisHost.nat or {});

  transitVlan = conventions.transitVlan;
  vlanIds = dt.dhcpVlans ++ [transitVlan];

  vlanIface = id: "bond0.${builtins.toString id}";
  vlanNetdev = id: {
    netdevConfig = {
      Name = vlanIface id;
      Kind = "vlan";
    };
    vlanConfig.Id = id;
  };
  vlanNetdevPair = id:
    lib.nameValuePair
    "31-${vlanIface id}"
    (vlanNetdev id);

  mkVlanNetwork = vlanId: let
    name = dt.vlanNameMap.${toString vlanId};
    net = dt.networks.${name};
  in {
    matchConfig.Name = vlanIface vlanId;
    address = [
      "${net.gateway4}/${toString net.prefixLen}"
      "${net.gateway6}/64"
    ];
    networkConfig = {
      IPv6SendRA = true;
      DHCPPrefixDelegation = true;
    };
    dhcpPrefixDelegationConfig = {
      SubnetId = net.ipv6PdSubnetId;
      Token = "::1";
    };
    ipv6SendRAConfig = {
      Managed = true;
      OtherInformation = true;
      DNS = "_link_local";
    };
    linkConfig.RequiredForOnline = "routable";
  };
in {
  config = lib.mkIf (config.psyclyx.nixos.host == "iyr") {
    networking.firewall = {
      enable = true;
      trustedInterfaces =
        ["bond0"]
        ++ map (id: "bond0.${toString id}") dt.dhcpVlans;
    };

    networking.nat = {
      enable = true;
      externalInterface = "bond0.${toString transitVlan}";
      internalInterfaces = map (id: "bond0.${toString id}") dt.dhcpVlans;

      extraCommands = lib.concatMapStringsSep "\n" (r: ''
        iptables -t nat -A PREROUTING -d ${r.natPrefix} -j NETMAP --to ${r.realPrefix}
        iptables -t nat -A POSTROUTING -s ${r.realPrefix} -o wg0 -j NETMAP --to ${r.natPrefix}
      '') natRules;

      extraStopCommands = lib.concatMapStringsSep "\n" (r: ''
        iptables -t nat -D PREROUTING -d ${r.natPrefix} -j NETMAP --to ${r.realPrefix} || true
        iptables -t nat -D POSTROUTING -s ${r.realPrefix} -o wg0 -j NETMAP --to ${r.natPrefix} || true
      '') natRules;
    };

    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
    boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

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
        // (builtins.listToAttrs (map vlanNetdevPair vlanIds));

      networks = let
        vlanUnit = id: "31-bond0.${builtins.toString id}";
      in
        {
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

            vlan = map vlanIface vlanIds;
          };
        }
        // builtins.listToAttrs (map (id: lib.nameValuePair (vlanUnit id) (mkVlanNetwork id)) dt.dhcpVlans)
        // {
          "${vlanUnit transitVlan}" = {
            matchConfig.Name = vlanIface transitVlan;
            networkConfig = {
              DHCP = "yes";
              IPv6AcceptRA = true;
              DHCPPrefixDelegation = true;
            };
            dhcpV4Config.UseRoutes = true;
            dhcpV6Config = {
              PrefixDelegationHint = "::/60";
              WithoutRA = "solicit";
            };
            linkConfig.RequiredForOnline = "carrier";
          };
        };
    };
  };
}
