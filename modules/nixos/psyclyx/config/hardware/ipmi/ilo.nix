{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.hardware.ipmi.ilo;
in
{
  options = {
    psyclyx.hardware.ipmi.ilo = {
      enable = lib.mkEnableOption "HPE Integrated Lights Out";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.initrd.availableKernelModules = [ "hpilo" ];
  };
}
