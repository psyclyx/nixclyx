{
  config,
  lib,
  pkgs,
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

  transitIface = vlanIface transitVlan;

  # CAKE bandwidth ranges (kbps).  cake-autorate continuously adjusts the
  # shaper between min and max based on measured latency.  "base" is the
  # starting point after (re)start.
  #
  # 2 Gbps symmetric DOCSIS 4, overprovisioned to ~2.4 Gbps.
  # Max set to 2280 Mbps (2.4 G × 0.95) — cake-autorate will ratchet
  # down from there whenever it detects latency.
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
  config = lib.mkIf (config.psyclyx.nixos.host == "iyr") {
    boot.kernelModules = ["sch_cake" "ifb"];

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

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      # Egress (upload): shape outbound on transit interface.
      #   diffserv4  — 4-tin priority (Bulk / Best Effort / Video / Voice)
      #   nat        — look through NAT for per-flow fairness
      #   docsis     — DOCSIS framing overhead compensation
      #   ack-filter — suppress redundant TCP ACKs (helps DL throughput)
      #   split-gso  — split GSO super-packets for accurate scheduling
      #
      # Ingress (download): redirect inbound into an IFB device and shape
      # there.  Same parameters plus:
      #   wash       — clear ISP-set DSCP marks
      #   ingress    — tell CAKE this is the ingress path
      #
      # Initial bandwidths are "base" values; cake-autorate adjusts them
      # dynamically based on measured latency.
      script = ''
        # --- egress (upload) ---
        tc qdisc replace dev ${transitIface} root cake \
          bandwidth ${toString cake.ul.base}kbit \
          diffserv4 nat docsis ack-filter split-gso

        # --- ingress (download) via IFB ---
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

    # cake-autorate: continuously monitors RTT and adjusts CAKE bandwidth
    # to track the actual available capacity on the DOCSIS link.
    systemd.services.cake-autorate = {
      description = "CAKE autorate bandwidth adjustment";
      after = ["cake-qos.service"];
      requires = ["cake-qos.service"];
      wantedBy = ["multi-user.target"];

      path = [pkgs.iproute2 pkgs.fping pkgs.gzip pkgs.coreutils];

      environment = {
        CAKE_AUTORATE_SCRIPT_PREFIX = "${cakeAutorate}/lib/cake-autorate";
      };

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

    networking.firewall = {
      enable = true;
      trustedInterfaces =
        ["bond0"]
        ++ map (id: "bond0.${toString id}") dt.dhcpVlans;

      extraCommands = let
        wan = vlanIface transitVlan;
        vpnPort = toString topo.wireguard.port;
      in ''
        # Lockdown WAN interface (${wan}): drop unsolicited inbound except
        # DHCP, ICMP, and WireGuard. Services that open firewall ports
        # globally (SSH, prometheus, etc.) won't be reachable from WAN.
        iptables -N nixos-fw-wan 2>/dev/null || iptables -F nixos-fw-wan
        iptables -A nixos-fw-wan -p icmp -j RETURN
        iptables -A nixos-fw-wan -p udp --sport 67 --dport 68 -j RETURN
        iptables -A nixos-fw-wan -p udp --dport ${vpnPort} -j RETURN
        iptables -A nixos-fw-wan -j DROP
        iptables -I nixos-fw -i ${wan} -m conntrack --ctstate NEW -j nixos-fw-wan

        ip6tables -N nixos-fw-wan 2>/dev/null || ip6tables -F nixos-fw-wan
        ip6tables -A nixos-fw-wan -p icmpv6 -j RETURN
        ip6tables -A nixos-fw-wan -p udp --dport 546 -j RETURN
        ip6tables -A nixos-fw-wan -p udp --dport ${vpnPort} -j RETURN
        ip6tables -A nixos-fw-wan -j DROP
        ip6tables -I nixos-fw -i ${wan} -m conntrack --ctstate NEW -j nixos-fw-wan
      '';

      extraStopCommands = let
        wan = vlanIface transitVlan;
      in ''
        iptables -D nixos-fw -i ${wan} -m conntrack --ctstate NEW -j nixos-fw-wan 2>/dev/null || true
        iptables -F nixos-fw-wan 2>/dev/null || true
        iptables -X nixos-fw-wan 2>/dev/null || true

        ip6tables -D nixos-fw -i ${wan} -m conntrack --ctstate NEW -j nixos-fw-wan 2>/dev/null || true
        ip6tables -F nixos-fw-wan 2>/dev/null || true
        ip6tables -X nixos-fw-wan 2>/dev/null || true
      '';
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
