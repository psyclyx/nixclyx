{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkDefault mkEnableOption;

  cfg = config.psyclyx.hardware.cpu.amd;
in
{
  options = {
    psyclyx.hardware.cpu.amd = {
      enable = mkEnableOption "AMD CPU config (currently only Ryzen 5950x)";
    };
  };

  config = lib.mkIf cfg.enable {
    boot = {
      kernelParams = [ "amd_pstate=active" ];
      kernelModules = [ "kvm-amd" ];
    };

    hardware = {
      cpu.amd.updateMicrocode = true;
      enableRedistributableFirmware = true;
    };

    powerManagement.cpuFreqGovernor = "performance";

    psyclyx.system.virtualization.enable = mkDefault true;
  };
}
