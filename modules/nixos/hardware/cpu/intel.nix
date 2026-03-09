{
  path = ["psyclyx" "nixos" "hardware" "cpu" "intel"];
  description = "Intel CPU config (tested on i5-8350U)";
  config = _: {
    nixpkgs.hostPlatform = "x86_64-linux";

    boot = {
      kernelModules = ["kvm-intel" "vfio_pci" "vfio" "vfio_iommu_type1"];
      kernelParams = ["intel_iommu=on" "iommu=pt"];
    };

    hardware = {
      cpu.intel.updateMicrocode = true;
      enableRedistributableFirmware = true;
    };
  };
}
