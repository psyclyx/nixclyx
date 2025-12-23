{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.psyclyx.nixos.boot.systemd-boot;
in
{
  options = {
    psyclyx.nixos.boot.systemd-boot = {
      enable = mkEnableOption "systemd-boot";
    };
  };

  config = mkIf cfg.enable {
    boot = {
      loader = {
        efi.canTouchEfiVariables = true;
        systemd-boot = {
          enable = true;
          configurationLimit = 16;
        };

        timeout = 1;
      };
    };
  };
}
