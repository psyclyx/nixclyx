{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption;

  cfg = config.psyclyx.hardware.cpu.amd;
in
{
  options = {
    psyclyx.hardware.cpu.amd = {
      enable = mkEnableOption "AMD CPU config (currently only Ryzen 5950x)";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.hostPlatform = "x86_64-linux";

    boot = {
      kernelParams = [ "amd_pstate=active" ];
      extraModulePackages = [ config.boot.kernelPackages.zenpower ];
      kernelModules = [
        "kvm_amd"
        "zenpower"
      ];
    };

    environment.systemPackages = [
      pkgs.ryzen-monitor-ng
      pkgs.zenstates
      pkgs.corectrl
    ];

    hardware = {
      cpu.amd = {
        ryzen-smu.enable = true;
        updateMicrocode = true;
      };
      enableRedistributableFirmware = true;
    };

    powerManagement.cpuFreqGovernor = "performance";
  };
}
