{
  path = ["psyclyx" "nixos" "hardware" "gpu" "intel"];
  description = "Intel integrated graphics (i915)";
  config = _: {
    boot = {
      kernelParams = [
        "i915.enable_guc=2"
        "i915.enable_fbc=1"
        "i915.enable_psr=0"
      ];
      initrd.kernelModules = ["i915"];
    };
  };
}
