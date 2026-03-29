{config, lib, pkgs, ...}: let
  eg = config.psyclyx.egregore;

  networks = lib.filterAttrs (_: e: e.type == "network") eg.entities;

  # Sorted VLAN IDs for all networks.
  dhcpVlans = lib.sort builtins.lessThan
    (lib.mapAttrsToList (_: e: e.network.vlan) networks);

  # VLAN ID → network entity name.
  vlanNameMap = builtins.listToAttrs (lib.mapAttrsToList (name: e:
    lib.nameValuePair (toString e.network.vlan) name
  ) networks);

  lanIface = "enp1s0";
  wanIface = "enp3s0";

  transitVlan = eg.conventions.transitVlan;

  vlanIface = id: "${lanIface}.${builtins.toString id}";
  transitIface = "${wanIface}.${builtins.toString transitVlan}";

  vlanNetdev = id: {
    netdevConfig = {
      Name = vlanIface id;
      Kind = "vlan";
    };
    vlanConfig.Id = id;
  };
  vlanNetdevPair = id:
    lib.nameValuePair "31-${vlanIface id}" (vlanNetdev id);

  mkVlanNetwork = vlanId: let
    name = vlanNameMap.${toString vlanId};
    net = eg.entities.${name};
    na = net.attrs;
  in {
    matchConfig.Name = vlanIface vlanId;
    address = [
      "${na.gateway4}/${toString na.prefixLen}"
      "${na.gateway6}/64"
    ];
    networkConfig = {
      IPv6SendRA = true;
      DHCPPrefixDelegation = true;
    };
    dhcpPrefixDelegationConfig = {
      SubnetId = net.network.ipv6PdSubnetId;
      Token = "::1";
    };
    ipv6SendRAConfig = {
      Managed = true;
      OtherInformation = true;
      DNS = "_link_local";
      Domains = "${na.zoneName} ${eg.domains.home} ${eg.domains.internal}";
    };
    ipv6Prefixes = [
      { Prefix = "${eg.ipv6UlaPrefix}:${net.network.ulaSubnetHex}::/64"; }
    ];
    linkConfig.RequiredForOnline = "routable";
  };

  cake = {
    dl = { min = 1400000; base = 2000000; max = 2280000; };
    ul = { min =  700000; base = 1400000; max = 2280000; };
  };

  cakeAutorate = pkgs.stdenvNoCC.mkDerivation {
    pname = "cake-autorate";
    version = "3.2.2";
    src = pkgs.fetchFromGitHub {
      owner = "lynxthecat";
      repo = "cake-autorate";
      rev = "v3.2.2";
      hash = "sha256-2WnMmilrVgVwjHK5ZkoXrzVlofuvvwQbSROfvd4RbEk=";
    };
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/lib/cake-autorate
      cp cake-autorate.sh lib.sh defaults.sh $out/lib/cake-autorate/
      chmod +x $out/lib/cake-autorate/cake-autorate.sh
    '';
  };
in {
  boot.kernelModules = ["sch_cake" "ifb"];

  psyclyx.nixos.boot.initrd-ssh.network = let
    initrdVlans = [eg.entities.main.network.vlan eg.entities.mgmt.network.vlan];
    mkInitrdVlanNetwork = vlanId: let
      name = vlanNameMap.${toString vlanId};
      na = eg.entities.${name}.attrs;
    in {
      matchConfig.Name = vlanIface vlanId;
      address = ["${na.gateway4}/${toString na.prefixLen}"];
      linkConfig.RequiredForOnline = "routable";
    };
  in {
    kernelModules = ["8021q" "igc"];
    netdevs =
      builtins.listToAttrs (map (id:
        lib.nameValuePair "11-${vlanIface id}" (vlanNetdev id)
      ) initrdVlans);
    networks =
      {
        "10-${lanIface}" = {
          matchConfig.Name = lanIface;
          networkConfig.DHCP = "no";
          vlan = map vlanIface initrdVlans;
          linkConfig.RequiredForOnline = "carrier";
        };
      }
      // builtins.listToAttrs (map (id:
        lib.nameValuePair "11-${vlanIface id}" (mkInitrdVlanNetwork id)
      ) initrdVlans);
  };

  systemd.services.cake-qos = {
    description = "CAKE traffic shaping on ${transitIface}";
    after = [
      "systemd-networkd.service"
      "sys-subsystem-net-devices-${transitIface}.device"
    ];
    requires = ["sys-subsystem-net-devices-${transitIface}.device"];
    bindsTo = ["sys-subsystem-net-devices-${transitIface}.device"];
    wantedBy = ["multi-user.target"];
    path = [pkgs.iproute2];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    script = ''
      tc qdisc replace dev ${transitIface} root cake \
        bandwidth ${toString cake.ul.base}kbit \
        diffserv4 nat docsis ack-filter split-gso
      ip link add ifb-transit type ifb 2>/dev/null || true
      ip link set ifb-transit up
      tc qdisc replace dev ${transitIface} handle ffff: ingress
      tc filter replace dev ${transitIface} parent ffff: matchall \
        action mirred egress redirect dev ifb-transit
      tc qdisc replace dev ifb-transit root cake \
        bandwidth ${toString cake.dl.base}kbit \
        diffserv4 nat wash docsis ingress split-gso
    '';
    preStop = ''
      tc qdisc del dev ${transitIface} root 2>/dev/null || true
      tc qdisc del dev ${transitIface} handle ffff: ingress 2>/dev/null || true
      ip link del ifb-transit 2>/dev/null || true
    '';
  };

  systemd.services.cake-autorate = {
    description = "CAKE autorate bandwidth adjustment";
    after = ["cake-qos.service"];
    requires = ["cake-qos.service"];
    wantedBy = ["multi-user.target"];
    path = [pkgs.iproute2 pkgs.fping pkgs.gzip pkgs.coreutils pkgs.gawk];
    environment.CAKE_AUTORATE_SCRIPT_PREFIX = "${cakeAutorate}/lib/cake-autorate";
    serviceConfig = {
      ExecStart = "${cakeAutorate}/lib/cake-autorate/cake-autorate.sh /etc/cake-autorate/config.primary.sh";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  environment.etc."cake-autorate/config.primary.sh".text = lib.concatStringsSep "\n" [
    "dl_if=ifb-transit"
    "ul_if=${transitIface}"
    ""
    "adjust_dl_shaper_rate=1"
    "adjust_ul_shaper_rate=1"
    ""
    "min_dl_shaper_rate_kbps=${toString cake.dl.min}"
    "base_dl_shaper_rate_kbps=${toString cake.dl.base}"
    "max_dl_shaper_rate_kbps=${toString cake.dl.max}"
    ""
    "min_ul_shaper_rate_kbps=${toString cake.ul.min}"
    "base_ul_shaper_rate_kbps=${toString cake.ul.base}"
    "max_ul_shaper_rate_kbps=${toString cake.ul.max}"
    ""
    "pinger_binary=fping"
    ""
    "connection_active_thr_kbps=5000"
  ];

  psyclyx.nixos.network.firewall = let
    internal = [lanIface] ++ map vlanIface dhcpVlans;
  in {
    enable = true;
    zones = {
      lan.interfaces = internal ++ ["wg0"];
      wan.interfaces = [transitIface];
    };
    input = {
      lan.policy = "accept";
      wan = {
        policy = "drop";
        allowICMP = true;
        allowedTCPPorts = config.psyclyx.nixos.network.ports.ssh.tcp;
        rules = [
          {"udp sport" = 67; "udp dport" = 68; comment = "DHCPv4 client";}
          {"udp dport" = 546; comment = "DHCPv6 client";}
        ];
      };
    };
    forward = [
      {from = "lan"; to = "wan";}
      {from = "lan"; to = "lan";}
    ];
    masquerade = [
      {from = "lan"; to = "wan";}
    ];
  };

  systemd.network.config.dhcpV6Config.DUIDType = "link-layer";

  systemd.network.netdevs =
    builtins.listToAttrs (map vlanNetdevPair dhcpVlans)
    // {
      "31-${transitIface}" = {
        netdevConfig = { Name = transitIface; Kind = "vlan"; };
        vlanConfig.Id = transitVlan;
      };
      "30-wg0".wireguardConfig.ListenPort = 51820;
      "30-wg0".wireguardPeers = lib.mkAfter [
        {
          PublicKey = "XKqqjC62uOUhbCn3JPpI0M6WFYqRf8sLpML90JZ1CmE=";
          AllowedIPs = ["10.157.0.3/32"];
        }
      ];
    };

  systemd.network.networks = let
    vlanUnit = id: "31-${vlanIface id}";
  in
    {
      "30-${lanIface}" = {
        matchConfig.Name = lanIface;
        linkConfig = {
          RequiredForOnline = "carrier";
          MACAddress = "c8:ff:bf:06:2c:4e";
        };
        networkConfig = { Domains = ["~."]; DHCP = "no"; };
        address = ["10.0.0.11/24"];
        dns = ["127.0.0.1"];
        vlan = map vlanIface dhcpVlans;
      };
      "30-${wanIface}" = {
        matchConfig.Name = wanIface;
        linkConfig = { RequiredForOnline = "carrier"; MACAddress = "c8:ff:bf:06:2c:4d"; };
        networkConfig.DHCP = "no";
        vlan = [transitIface];
      };
    }
    // builtins.listToAttrs (map (id: lib.nameValuePair (vlanUnit id) (mkVlanNetwork id)) dhcpVlans)
    // {
      "31-${transitIface}" = {
        matchConfig.Name = transitIface;
        networkConfig = { DHCP = "yes"; IPv6AcceptRA = true; };
        dhcpV4Config = { UseRoutes = true; ClientIdentifier = "duid"; };
        dhcpV6Config = {
          PrefixDelegationHint = "::/60";
          WithoutRA = "solicit";
          UseAddress = false;
          RapidCommit = true;
          IAID = 250;
          DUIDType = "uuid";
          DUIDRawData = "e7:13:f8:92:37:c5:be:76";
        };
        routes = [{ Destination = "::/0"; Metric = 1024; }];
        linkConfig.RequiredForOnline = "carrier";
      };
    };
}
