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

  # Bond slave devices (1G NICs).
  bondSlaves = ["eno1" "eno2" "eno3" "eno4"];

  # VLANs carried over the bond.
  bondVlans = [
    { name = "main";  id = 10; }
    { name = "infra"; id = 25; }
    { name = "stage"; id = 31; }
  ];

  # Networks that live directly on a physical device (not the bond).
  directNetworks = lib.filterAttrs (name: _:
    !builtins.elem name (map (v: v.name) bondVlans)
  ) hostNetworks;

  mkDirectNetworkUnit = netName: _addr: let
    device = me.interfaces.${netName}.device;
    addr = me.addresses.${netName};
    net = eg.entities.${netName}.attrs;
    prefixLen = toString net.prefixLen;
  in {
    matchConfig.Name = device;
    address =
      ["${addr.ipv4}/${prefixLen}"]
      ++ lib.optional (addr.ipv6 != null) "${addr.ipv6}/64";
    networkConfig.IPv6AcceptRA = true;
    linkConfig.RequiredForOnline = "no";
  };

  directNetworkUnits = lib.mapAttrs' (netName: addr:
    lib.nameValuePair "20-${me.interfaces.${netName}.device}" (mkDirectNetworkUnit netName addr)
  ) directNetworks;

  # Bond VLAN network units.
  # Non-default VLANs get source-based policy routing so replies
  # route back through iyr rather than directly on the main VLAN.
  mkVlanNetworkUnit = vlan: let
    addr = me.addresses.${vlan.name};
    net = eg.entities.${vlan.name}.attrs;
    prefixLen = toString net.prefixLen;
    isDefault = vlan.name == "infra";
  in {
    matchConfig.Name = "bond0.${toString vlan.id}";
    address =
      ["${addr.ipv4}/${prefixLen}"]
      ++ lib.optional (addr.ipv6 != null) "${addr.ipv6}/64";
    routes =
      if isDefault then [{ Gateway = net.gateway4; }]
      else [{ Gateway = net.gateway4; Table = vlan.id; }];
    routingPolicyRules =
      lib.optional (!isDefault) { From = "${addr.ipv4}/32"; Table = vlan.id; Priority = 100; };
    dns = lib.optional isDefault net.gateway4;
    networkConfig.IPv6AcceptRA = true;
    linkConfig.RequiredForOnline =
      if isDefault then "routable" else "no";
  };

  vlanNetworkUnits = builtins.listToAttrs (map (vlan:
    lib.nameValuePair "20-bond0.${toString vlan.id}" (mkVlanNetworkUnit vlan)
  ) bondVlans);

  # Bond netdev + network + slave + VLAN netdev units (shared between initrd and real system).
  bondNetdevs = {
    "10-bond0" = {
      netdevConfig = { Name = "bond0"; Kind = "bond"; MACAddress = me.mac.eno1; };
      bondConfig = { Mode = "balance-xor"; MIIMonitorSec = "0.1"; TransmitHashPolicy = "layer2+3"; };
    };
  } // builtins.listToAttrs (map (vlan:
    lib.nameValuePair "10-bond0.${toString vlan.id}" {
      netdevConfig = { Name = "bond0.${toString vlan.id}"; Kind = "vlan"; };
      vlanConfig.Id = vlan.id;
    }
  ) bondVlans);

  bondNetworks = {
    "10-bond-slaves" = {
      matchConfig.Name = lib.concatStringsSep " " bondSlaves;
      networkConfig.Bond = "bond0";
      linkConfig.RequiredForOnline = "enslaved";
    };
    "10-bond0" = {
      matchConfig.Name = "bond0";
      networkConfig.VLAN = map (v: "bond0.${toString v.id}") bondVlans;
      linkConfig.RequiredForOnline = "carrier";
    };
  };

  allDevices =
    (map (v: "bond0.${toString v.id}") bondVlans)
    ++ lib.mapAttrsToList (netName: _: me.interfaces.${netName}.device) directNetworks;

  infraAddr = me.addresses.infra;
  infraNet = eg.entities.infra.attrs;
in {
  boot.initrd = {
    kernelModules = ["igb" "tg3" "bonding" "8021q"];
    systemd.network.netdevs = bondNetdevs;
    systemd.network.networks = bondNetworks // {
      "20-bond0.25" = {
        matchConfig.Name = "bond0.25";
        address = ["${infraAddr.ipv4}/${toString infraNet.prefixLen}"];
        routes = [{ Gateway = infraNet.gateway4; }];
        linkConfig.RequiredForOnline = "routable";
      };
    };
  };

  systemd.network.netdevs = bondNetdevs;
  systemd.network.networks = bondNetworks // vlanNetworkUnits // directNetworkUnits;

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
        tls = let etcdPki = "/run/openbao-pki/etcd"; in {
          certFile = "${etcdPki}/etcd.pem";
          keyFile = "${etcdPki}/etcd-key.pem";
          caFile = "${etcdPki}/ca.pem";
        };
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
      icecream = {
        enable = true;
        schedulerHost = "10.0.25.11"; # lab-1 infra
      };
    };
  };
}
