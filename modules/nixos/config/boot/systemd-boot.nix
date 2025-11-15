{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.boot.systemd-boot;
in
{
  options = {
    psyclyx.boot.systemd-boot = {
      enable = lib.mkEnableOption "systemd-boot";
    };
  };

  config = lib.mkIf cfg.enable {
    boot = {
      loader = {
        timeout = 1;
        systemd-boot = {
          enable = true;
          configurationLimit = 16;
        };
        efi.canTouchEfiVariables = true;
      };
      initrd.systemd.enable = true;
    };
  };
}
