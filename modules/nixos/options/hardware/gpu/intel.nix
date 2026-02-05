{
  path = ["psyclyx" "nixos" "hardware" "gpu" "intel"];
  description = "Intel graphics (i915 driver, kaby lake)";
  config = _: {
    boot = {
      kernelModules = ["kvm-intel"];
      kernelParams = [
        "i915.enable_guc=2"
        "i915.enable_fbc=1"
        "i915.enable_psr=0"
      ];
      initrd.kernelModules = ["i915"];
    };
  };
}
