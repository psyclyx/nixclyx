{ config, lib, ... }: let
  hostname = config.networking.hostName;
  eg = config.psyclyx.egregore;

  labHostNames = let
    labHosts = lib.filterAttrs (_: e:
      e.type == "host" && builtins.elem "lab" (e.host.roles or [])
    ) eg.entities;
  in
    lib.sort builtins.lessThan (lib.attrNames labHosts);
in {
  psyclyx.nixos = {
    boot.initrd-ssh.enable = true;

    hardware.presets.hpe.dl360-gen9.enable = true;

    network = {
      interfaces = {
        bonds.bond0 = {
          slaves = ["eno1" "eno2" "eno3" "eno4"];
          mac = eg.entities.${hostname}.host.mac.eno1;
        };
        initrd = {
          enable = true;
          kernelModules = ["igb" "tg3" "bonding" "8021q"];
        };
      };

      topology = {
        enable = true;
        defaultNetwork = "infra";
      };

      firewall = {
        input.lan.policy = "accept";
        forward = [{ from = "lan"; to = "lan"; }];
        zones.lan.interfaces = ["eno49np0" "eno50np1"];
      };
    };

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
        schedulerHost = "10.0.25.11";
      };
    };
  };

  boot.kernel.sysctl."kernel.sched_autogroup_enabled" = 0;
  boot.supportedFilesystems = ["bcachefs"];
}
