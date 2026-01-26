{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.nixos.hardware.cpu.intel;
in
{
  options = {
    psyclyx.nixos.hardware.cpu.intel = {
      enable = lib.mkEnableOption "Intel CPU config (tested on i5-8350U)";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.hostPlatform = "x86_64-linux";

    boot.kernelModules = [ "kvm-intel" ];

    hardware = {
      cpu.intel.updateMicrocode = true;
      enableRedistributableFirmware = true;
    };
  };
}
