{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.psyclyx.boot.systemd-initrd;
in
{
  options = {
    psyclyx.boot.systemd-initrd = {
      enable = mkEnableOption "systemd initrd";
    };
  };

  config = mkIf cfg.enable {
    boot.initrd = {
      network.flushBeforeStage2 = true;

      systemd = {
        enable = true;
        network.enable = true;
      };
    };
  };
}
