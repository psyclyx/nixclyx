{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkDefault
    mkEnableOption
    mkIf
    optionals
    ;

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

    psyclyx.system.virtualization.enable = mkDefault true;

    hardware = {
      cpu.intel.updateMicrocode = true;
      enableRedistributableFirmware = true;
    };
  };
}
