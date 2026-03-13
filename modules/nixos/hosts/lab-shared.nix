{
  path = [
    "psyclyx"
    "nixos"
    "hosts"
    "lab"
    "shared"
  ];
  gate =
    {
      config,
      lib,
      ...
    }:
    lib.hasPrefix "lab-" config.psyclyx.nixos.host;
  config =
    { config, lib, ... }:
    let
      labHostNames =
        let
          labHosts = lib.filterAttrs (_: h: h.labIndex != null) config.psyclyx.topology.hosts;
        in
        lib.mapAttrsToList (name: _: name) labHosts;
      thisHost = config.psyclyx.topology.hosts.${config.psyclyx.nixos.host};

      mkBondNetdev = name: macIface: {
        netdevConfig = {
          Name = name;
          Kind = "bond";
          MACAddress = thisHost.mac.${macIface};
        };
        bondConfig = {
          Mode = "802.3ad";
          LACPTransmitRate = "fast";
          TransmitHashPolicy = "layer3+4";
          MIIMonitorSec = "100ms";
        };
      };

      mkBondPortNetwork = bondName: members: {
        matchConfig.Name = builtins.concatStringsSep " " members;
        networkConfig.Bond = bondName;
      };

      bond0Netdev = mkBondNetdev "bond0" "eno1";
      bond0PortNetwork = mkBondPortNetwork "bond0" [ "eno1" "eno2" ];
      bond1Netdev = mkBondNetdev "bond1" "eno3";
      bond1PortNetwork = mkBondPortNetwork "bond1" [ "eno3" "eno4" ];
    in
    {
      boot = {
        initrd = {
          kernelModules = ["bonding" "igb" "tg3"];
          systemd = {
            network = {
              netdevs = {
                "10-bond0" = bond0Netdev;
                "10-bond1" = bond1Netdev;
              };
              networks = {
                "10-bond0-ports" = bond0PortNetwork;
                "10-bond1-ports" = bond1PortNetwork;
                "20-bond0" = {
                  matchConfig.Name = "bond0";
                  DHCP = "ipv4";
                  dhcpV4Config.ClientIdentifier = "mac";
                };
                "20-bond1" = {
                  matchConfig.Name = "bond1";
                  DHCP = "ipv4";
                  dhcpV4Config.ClientIdentifier = "mac";
                };
              };
            };
          };
        };
      };

      systemd.network = {
        netdevs = {
          "10-bond0" = bond0Netdev;
          "10-bond1" = bond1Netdev;
        };
        networks = {
          "10-bond0-ports" = bond0PortNetwork;
          "10-bond1-ports" = bond1PortNetwork;
          "20-bond0" = {
            matchConfig.Name = "bond0";
            DHCP = "yes";
            networkConfig.IPv6AcceptRA = true;
            dhcpV4Config = {
              ClientIdentifier = "mac";
              UseDomains = true;
            };
            dhcpV6Config.WithoutRA = "solicit";
            linkConfig.RequiredForOnline = "routable";
          };
          "20-bond1" = {
            matchConfig.Name = "bond1";
            DHCP = "yes";
            networkConfig.IPv6AcceptRA = true;
            dhcpV4Config = {
              ClientIdentifier = "mac";
              UseDomains = true;
            };
            dhcpV6Config.WithoutRA = "solicit";
            linkConfig.RequiredForOnline = "no";
          };
        };
      };

      psyclyx.nixos.network.firewall = {
        zones.lan.interfaces = ["bond0" "bond1"];
        input.lan.policy = "accept";
      };

      psyclyx.nixos.system.swap.swappiness = 10;

      # TCP/IP tuning is now in network/tuning.nix (applies to all hosts).
      # Lab-specific sysctls only:
      boot.kernel.sysctl = {
        # Scheduler: disable desktop autogroup for proper CFS fairness
        "kernel.sched_autogroup_enabled" = 0;
        # VM: reduce VFS cache pressure (ZFS manages its own caching via ARC)
        "vm.vfs_cache_pressure" = 50;
      };

      services.prometheus.exporters.redis = {
        enable = true;
        openFirewall = true;
        extraFlags = [
          "--redis.addr=${config.services.redis.servers.jfs.bind}:${toString config.services.redis.servers.jfs.port}"
        ];
      };

      services.prometheus.exporters.postgres = {
        enable = true;
        openFirewall = true;
      };

      psyclyx.nixos = {
        boot = {
          initrd-ssh.enable = true;
        };

        hardware.presets.hpe.dl360-gen9.enable = true;

        role = "server";

        services = {
          seaweedfs = {
            enable = true;
            clusterNodes = labHostNames;
            masterNodes = let
              labHosts = lib.filterAttrs (_: h: h.labIndex != null) config.psyclyx.topology.hosts;
              sorted = lib.sort (a: b: labHosts.${a}.labIndex < labHosts.${b}.labIndex)
                (lib.attrNames labHosts);
            in lib.take 3 sorted;
            s3.enable = true;
            buckets = ["backups" "attic"];
          };
          attic = {
            enable = true;
            clusterNodes = labHostNames;
          };
          redis-sentinel = {
            enable = true;
            clusterNodes = labHostNames;
          };
          etcd-cluster = {
            enable = true;
            clusterNodes = labHostNames;
          };
          patroni = {
            enable = true;
            clusterNodes = labHostNames;
          };
        };
      };
    };
}
