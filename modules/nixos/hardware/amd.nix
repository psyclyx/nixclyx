{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.hardware.amd;
in
{
  options = {
    psyclyx.hardware.amd = {
      enable = lib.mkEnableOption "AMD CPU config (currently only Ryzen 5950x)";
    };
  };

  config = lib.mkIf cfg.enable {
    powerManagement.cpuFreqGovernor = "performance";
    boot = {
      kernelParams = [ "amd_pstate=active" ];
      kernelModules = [ "kvm-amd" ];
    };
    hardware = {
      cpu.amd.updateMicrocode = true;
      enableRedistributableFirmware = true;
    };
  };
}
