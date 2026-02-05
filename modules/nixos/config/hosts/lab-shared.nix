{
  path = ["psyclyx" "nixos" "config" "hosts" "lab" "shared"];
  gate = {config, lib, ...}: lib.hasPrefix "lab-" config.psyclyx.nixos.host;
  config = {lib, ...}: {
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

    psyclyx.nixos = {
      boot = {
        initrd-ssh.enable = true;
      };

      filesystems.layouts.bcachefs-pool.enable = true;

      hardware.presets.hpe.dl360-gen9.enable = true;

      role = "server";
    };
  };
}
