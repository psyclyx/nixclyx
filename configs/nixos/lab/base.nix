{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.self.nixosModules.psyclyx
  ];

  config = {
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

    environment.systemPackages = [
      pkgs.psyclyx.envs.forensics
    ];

    psyclyx = {
      filesystems.layouts.bcachefs-pool.enable = true;

      nixos = {
        boot = {
          initrd-ssh.enable = true;
        };

        hardware.presets.hpe.dl360-gen9.enable = true;
      };

      roles = {
        base.enable = true;
        remote.enable = true;
        utility.enable = true;
      };

      users.psyc = {
        enable = true;
        server = true;
      };
    };
  };
}
