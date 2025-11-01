{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.psyclyx.hardware.ipmi.ilo;
in
{
  options = {
    psyclyx.hardware.ipmi.ilo = {
      enable = mkEnableOption "HPE Integrated Lights Out";
    };
  };

  config = mkIf cfg.enable {
    initrd.availableKernelModules = [ "hpilo" ];
  };
}
