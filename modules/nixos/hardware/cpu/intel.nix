{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.hardware.cpu.intel;
in
{
  options = {
    psyclyx.hardware.cpu.intel = {
      enable = lib.mkEnableOption "Intel CPU config (tested on i5-8350U)";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelParams = [ "snd-intel-dspcfg.dsp_driver=1" ];
    hardware = {
      cpu.intel.updateMicrocode = true;
      enableRedistributableFirmware = true;
    };
  };
}
