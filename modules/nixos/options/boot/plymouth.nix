{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.nixos.boot.plymouth;
in {
  options = {
    psyclyx.nixos.boot.plymouth = {
      enable = lib.mkEnableOption "graphical startup";
    };
  };

  config = lib.mkIf cfg.enable {
    boot = {
      plymouth.enable = true;
      initrd.verbose = false;
      kernelParams = [
        "quiet"
        "udev.log_priority=3"
        "rd.systemd.show_status=auto"
      ];
    };
  };
}
