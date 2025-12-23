{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.psyclyx.hardware.cpu.intel;
in
{
  options = {
    psyclyx.hardware.cpu.intel = {
      enable = mkEnableOption "Intel CPU config (tested on i5-8350U)";
    };
  };

  config = mkIf cfg.enable {
    nixpkgs.hostPlatform = "x86_64-linux";

    boot.kernelModules = [ "kvm-intel" ];

    hardware = {
      cpu.intel.updateMicrocode = true;
      enableRedistributableFirmware = true;
    };
  };
}
