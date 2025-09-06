{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.hardware.cpu;
in
{
  imports = [ ./amd.nix ];

  options = {
    psyclyx.hardware.cpu = {
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
