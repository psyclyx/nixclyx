{
  path = ["psyclyx" "nixos" "config" "hosts" "lab" "shared"];
  gate = {
    config,
    lib,
    ...
  }:
    lib.hasPrefix "lab-" config.psyclyx.nixos.host;
  config = {config, lib, ...}: {
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

    networking.firewall.trustedInterfaces = ["eno4"];

    psyclyx.nixos = {
      boot = {
        initrd-ssh.enable = true;
      };

      filesystems.layouts.bcachefs-pool.enable = true;

      hardware.presets.hpe.dl360-gen9.enable = true;

      role = "server";

      services.rustfs = {
        enable = true;
        clusterNodes = let
          labHosts = lib.filterAttrs (_: h: h.labIndex != null) config.psyclyx.topology.hosts;
        in
          lib.mapAttrsToList (name: _: name) labHosts;
      };
    };
  };
}
