{
  config,
  inputs,
  ...
}:
{
  imports = [ inputs.self.nixosModules.config ];

  config = {
    boot.initrd.systemd.enable = true;

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
