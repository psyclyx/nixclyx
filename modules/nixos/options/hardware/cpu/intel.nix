{nixclyx, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "hardware" "cpu" "intel"];
  description = "Intel CPU config (tested on i5-8350U)";
  config = _: {
    nixpkgs.hostPlatform = "x86_64-linux";

    boot.kernelModules = ["kvm-intel"];

    hardware = {
      cpu.intel.updateMicrocode = true;
      enableRedistributableFirmware = true;
    };
  };
} args
