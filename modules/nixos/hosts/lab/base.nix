{ ... }:
{
  imports = [ ./disks.nix ];

  config = {
    psyclyx = {
      hardware.presets.dl360-gen9.enable = true;

      boot.systemd-boot.enable = true;

      filesystem.bcachefs.enable = true;

      roles = {
        base.enable = true;
        remote.enable = true;
        utility.enable = true;
      };

      users.psyc = {
        enable = true;
        admin = true;
      };
    };
  };
}
