{ config, lib, ... }:
let
  cfg = config.psyclyx.hardware.gpu.intel;
in
{
  options = {
    psyclyx.hardware.gpu.intel = {
      enable = lib.mkEnableOption "Intel graphics (i915 driver, kaby lake)";
    };
  };

  config = lib.mkIf cfg.enable {
    boot = {
      kernelModules = [ "kvm-intel" ];
      kernelParams = [
        "i915.enable_guc=2"
        "i915.enable_fbc=1"
        "i915.enable_psr=0"
      ];
      initrd.availableKernelModules = [ "i915" ];
    };
  };
}
