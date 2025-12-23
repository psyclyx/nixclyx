{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.psyclyx.nixos.boot.plymouth;
in
{
  options = {
    psyclyx.nixos.boot.plymouth = {
      enable = mkEnableOption "graphical startup";
    };
  };

  config = mkIf cfg.enable {
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
