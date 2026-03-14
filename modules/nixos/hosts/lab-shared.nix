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
      hostname = config.psyclyx.nixos.host;
      topo = config.psyclyx.topology;
      fleet = config.psyclyx.fleet;
      thisHost = topo.hosts.${hostname};

      labHostNames =
        let
          labHosts = lib.filterAttrs (_: h: builtins.elem "lab" (h.roles or [])) topo.hosts;
        in
        lib.sort builtins.lessThan (lib.mapAttrsToList (name: _: name) labHosts);

      # Networks with both an interface mapping and an address on this host.
      # Excludes mgmt (iLO BMC, not host OS) and vpn (WireGuard, configured separately).
      hostNetworks = lib.filterAttrs (name: _:
        name != "mgmt" && name != "vpn"
        && thisHost.interfaces ? ${name}
        && thisHost.addresses ? ${name}
      ) thisHost.addresses;

      mkNetworkUnit = netName: _addr: let
        device = thisHost.interfaces.${netName}.device;
        addr = thisHost.addresses.${netName};
        net = fleet.networks.${netName};
        prefixLen = toString net.prefixLen;
        isDefault = netName == "infra";
      in {
        matchConfig.Name = device;
        address =
          ["${addr.ipv4}/${prefixLen}"]
          ++ lib.optional (addr ? ipv6) "${addr.ipv6}/64";
        routes = lib.optional isDefault {
          Gateway = net.gateway4;
        };
        dns = lib.optional isDefault net.gateway4;
        networkConfig.IPv6AcceptRA = true;
        linkConfig.RequiredForOnline = if isDefault then "routable" else "no";
      };

      networkUnits = lib.mapAttrs' (netName: addr:
        lib.nameValuePair "20-${thisHost.interfaces.${netName}.device}" (mkNetworkUnit netName addr)
      ) hostNetworks;

      allDevices = lib.mapAttrsToList (netName: _:
        thisHost.interfaces.${netName}.device
      ) hostNetworks;

      # Infra interface for initrd SSH (simplest, always available)
      infraDevice = thisHost.interfaces.infra.device;
      infraAddr = thisHost.addresses.infra;
      infraNet = fleet.networks.infra;
    in
    {
      boot.initrd = {
        kernelModules = ["igb" "tg3"];
        systemd.network.networks."20-${infraDevice}" = {
          matchConfig.Name = infraDevice;
          address = ["${infraAddr.ipv4}/${toString infraNet.prefixLen}"];
          routes = [{ Gateway = infraNet.gateway4; }];
          linkConfig.RequiredForOnline = "routable";
        };
      };

      systemd.network.networks = networkUnits;

      psyclyx.nixos.network.firewall = {
        zones.lan.interfaces = allDevices ++ ["wg0"];
        input.lan.policy = "accept";
      };

      boot.kernel.sysctl = {
        "kernel.sched_autogroup_enabled" = 0;
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
            masterNodes = lib.take 3 labHostNames;
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
          openbao = {
            enable = true;
            clusterNodes = labHostNames;
          };
        };
      };
    };
}
