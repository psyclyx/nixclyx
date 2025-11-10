{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;

  cfg = config.psyclyx.host;
in
{
  imports = [
    inputs.self.nixosModules.config
    ./disks.nix
  ];

  options = {
    psyclyx.host = {
      suffix = mkOption {
        type = types.str;
      };
    };
  };

  config = {
    networking = {
      hostName = "lab-${cfg.suffix}";
    };

    psyclyx = {
      hardware.presets.hpe.dl360-gen9.enable = true;

      boot.systemd-boot.enable = true;

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
