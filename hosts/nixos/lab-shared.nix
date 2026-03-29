{ config, lib, ... }: let
  hostname = config.networking.hostName;
  eg = config.psyclyx.egregore;
  me = eg.entities.${hostname}.host;

  labHostNames = let
    labHosts = lib.filterAttrs (_: e:
      e.type == "host" && builtins.elem "lab" (e.host.roles or [])
    ) eg.entities;
  in
    lib.sort builtins.lessThan (lib.attrNames labHosts);

  # Networks with both an interface mapping and an address on this host.
  # Excludes mgmt (iLO BMC, not host OS) and vpn (WireGuard, configured separately).
  hostNetworks =
    lib.filterAttrs (
      name: _:
        name != "mgmt"
        && name != "vpn"
        && me.interfaces ? ${name}
        && me.addresses ? ${name}
    )
    me.addresses;

  mkNetworkUnit = netName: _addr: let
    device = me.interfaces.${netName}.device;
    addr = me.addresses.${netName};
    net = eg.entities.${netName}.attrs;
    prefixLen = toString net.prefixLen;
    isDefault = netName == "infra";
  in {
    matchConfig.Name = device;
    address =
      ["${addr.ipv4}/${prefixLen}"]
      ++ lib.optional (addr.ipv6 != null) "${addr.ipv6}/64";
    routes = lib.optional isDefault {
      Gateway = net.gateway4;
    };
    dns = lib.optional isDefault net.gateway4;
    networkConfig.IPv6AcceptRA = true;
    linkConfig.RequiredForOnline =
      if isDefault
      then "routable"
      else "no";
  };

  networkUnits =
    lib.mapAttrs' (
      netName: addr:
        lib.nameValuePair "20-${me.interfaces.${netName}.device}" (mkNetworkUnit netName addr)
    )
    hostNetworks;

  allDevices =
    lib.mapAttrsToList (netName: _: me.interfaces.${netName}.device)
    hostNetworks;

  infraDevice = me.interfaces.infra.device;
  infraAddr = me.addresses.infra;
  infraNet = eg.entities.infra.attrs;
in {
  boot.initrd = {
    kernelModules = ["igb" "tg3"];
    systemd.network.networks."20-${infraDevice}" = {
      matchConfig.Name = infraDevice;
      address = ["${infraAddr.ipv4}/${toString infraNet.prefixLen}"];
      routes = [{Gateway = infraNet.gateway4;}];
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

  psyclyx.nixos = {
    boot = {
      initrd-ssh.enable = true;
    };

    hardware.presets.hpe.dl360-gen9.enable = true;

    role = "server";

    services = {
      seaweedfs = {
        enable = true;
        dataNetwork = "infra";
        clusterNodes = labHostNames;
        masterNodes = lib.take 3 labHostNames;
        s3.enable = true;
        buckets = ["backups" "angelbeats"];
      };
      redis-sentinel = {
        enable = true;
        dataNetwork = "infra";
        clusterNodes = labHostNames;
      };
      etcd-cluster = {
        enable = true;
        dataNetwork = "infra";
        clusterNodes = labHostNames;
      };
      patroni = {
        enable = true;
        dataNetwork = "infra";
        clusterNodes = labHostNames;
      };
      openbao = {
        enable = true;
        clusterNodes = labHostNames;
        settings.transitAddress = "http://${eg.entities.infra.attrs.gateway4}:8200";
      };
      openbao-pki.enable = true;
      openbao-kv.enable = true;
      kubernetes = {
        enable = true;
        clusterNodes = labHostNames;
      };
    };
  };
}
