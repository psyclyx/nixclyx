{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    ;

  cfg = config.psyclyx.hosts.lab;
in
{
  imports = [ ./disks.nix ];

  options = {
    psyclyx.hosts.lab = {
      enable = mkEnableOption "Base homelab server config";
    };
  };

  config = mkIf cfg.enable {
    psyclyx = {
      hardware.presets.dl360-gen9.enable = true;
      boot.systemd-boot.enable = true;
      filesystem.bcachefs.enable = true;
      roles = {
        base.enable = true;
        remote.enable = true;
        utility.enable = true;
      };
      users.psyc.enable = true;
    };
  };
}
