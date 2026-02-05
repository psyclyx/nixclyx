{nixclyx, lib, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "hardware" "cpu"];
  options = {
    enableMitigations =
      (lib.mkEnableOption "Runtime patches for CPU vulnerabilities. Whether or not this is worth the potential performance gains depends on workload, the specific CPU model in question (run benchmarks), and threat model.")
      // {
        default = true;
      };
  };
  gate = false;
  config = {cfg, lib, ...}: {
    boot.kernelParams = lib.optional (!cfg.enableMitigations) "mitigations=off";
  };
} args
