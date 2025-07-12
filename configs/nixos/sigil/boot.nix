{ ... }:
{
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    kernelParams = [
      "amd_iommu=on"
      "iommu=pt"
      "nvidia-drm.modeset=1"
    ];

    kernelModules = [
      "kvm-amd"
      "nvidia"
      "nvidia_drm"
      "nvidia_uvm"
    ];

    blacklistedKernelModules = [ "nouveau" ];
  };
}
