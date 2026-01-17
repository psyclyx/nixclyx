{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.nixos.boot.systemd.loader;
in
{
  options = {
    psyclyx.nixos.boot.systemd.loader = {
      enable = lib.mkEnableOption "systemd-boot";
    };
  };

  config = lib.mkIf cfg.enable {
    boot = {
      loader = {
        efi.canTouchEfiVariables = true;
        systemd-boot = {
          enable = true;
          configurationLimit = 8;
          consoleMode = "max";
        };

        timeout = 1;
      };
    };
  };
}
