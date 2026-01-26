{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.nixos.hardware.cpu;
in
{
  imports = [
    ./amd.nix
    ./intel.nix
  ];

  options = {
    psyclyx.nixos.hardware.cpu = {
      enableMitigations =
        (lib.mkEnableOption "Runtime patches for CPU vulnerabilities. Whether or not this is worth the potential performance gains depends on workload, the specific CPU model in question (run benchmarks), and threat model.")
        // {
          default = true;
        };
    };
  };

  config = {
    boot.kernelParams = lib.optional (!cfg.enableMitigations) "mitigations=off";
  };
}
