{
  path = [
    "psyclyx"
    "nixos"
    "config"
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

      networking.firewall.trustedInterfaces = [ "eno4" ];

      networking.firewall.allowedTCPPorts = [ 9567 ];

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
          rustfs = {
            enable = true;
            clusterNodes = labHostNames;
          };
          redis-sentinel = {
            enable = true;
            clusterNodes = labHostNames;
          };
          postgresql-cluster = {
            enable = true;
            clusterNodes = labHostNames;
          };
          juicefs = {
            enable = true;
            clusterNodes = labHostNames;
          };
        };
      };
    };
}
