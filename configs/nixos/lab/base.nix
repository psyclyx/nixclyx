{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;

  cfg = config.psyclyx.hosts.lab;
in
{
  imports = [
    inputs.self.nixosModules.config
    ./disks.nix
  ];

  config = {
    boot.kernelParams = [ "ip=::::${config.networking.hostName}::dhcp" ];

    psyclyx = {
      hardware.presets.hpe.dl360-gen9.enable = true;

      boot = {
        systemd-boot.enable = true;
        initrd-ssh.enable = true;
      };

      filesystems.bcachefs.enable = true;

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
