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
    in
    {
      boot = {
        initrd = {
          systemd = {
            network = {
              networks."10-ethernet-dhcp" = {
                enable = true;
                matchConfig.Name = "et* en*";
                DHCP = "yes";
              };
            };
          };
        };
      };

      systemd.network = {
        netdevs = {
          "10-bond0" = {
            netdevConfig = {
              Name = "bond0";
              Kind = "bond";
              MACAddress = thisHost.mac.eno1;
            };
            bondConfig = {
              Mode = "802.3ad";
              LACPTransmitRate = "fast";
              TransmitHashPolicy = "layer3+4";
              MIIMonitorSec = "100ms";
            };
          };
          "10-bond1" = {
            netdevConfig = {
              Name = "bond1";
              Kind = "bond";
              MACAddress = thisHost.mac.eno3;
            };
            bondConfig = {
              Mode = "802.3ad";
              LACPTransmitRate = "fast";
              TransmitHashPolicy = "layer3+4";
              MIIMonitorSec = "100ms";
            };
          };
        };
        networks = {
          "10-bond0-ports" = {
            matchConfig.Name = "eno1 eno2";
            networkConfig.Bond = "bond0";
          };
          "10-bond1-ports" = {
            matchConfig.Name = "eno3 eno4";
            networkConfig.Bond = "bond1";
          };
          "20-bond0" = {
            matchConfig.Name = "bond0";
            DHCP = "yes";
            dhcpV4Config.ClientIdentifier = "mac";
            linkConfig.RequiredForOnline = "routable";
          };
          "20-bond1" = {
            matchConfig.Name = "bond1";
            DHCP = "yes";
            dhcpV4Config.ClientIdentifier = "mac";
            linkConfig.RequiredForOnline = "no";
          };
        };
      };

      networking.firewall.trustedInterfaces = [ "bond0" "bond1" ];

      psyclyx.nixos.system.swap.swappiness = 10;

      boot.kernel.sysctl = {
        "net.core.rmem_max" = 16777216;
        "net.core.wmem_max" = 16777216;
        "net.ipv4.tcp_rmem" = "4096 87380 16777216";
        "net.ipv4.tcp_wmem" = "4096 65536 16777216";
        "net.ipv4.tcp_congestion_control" = "bbr";
        "net.core.default_qdisc" = "fq";
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

        filesystems.layouts.bcachefs-pool.enable = true;

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
