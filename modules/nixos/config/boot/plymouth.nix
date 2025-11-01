{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.boot.plymouth;
in
{
  options = {
    psyclyx.boot.plymouth = {
      enable = lib.mkEnableOption "graphical startup";
    };
  };

  config = lib.mkIf cfg.enable {
    boot = {
      plymouth.enable = true;
      initrd.verbose = false;
      kernelParams = [
        "quiet"
        "splash"
        "udev.log_priority=3"
        "rd.systemd.show_status=auto"
      ];
    };
  };
}
