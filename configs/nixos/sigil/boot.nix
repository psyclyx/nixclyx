{ inputs, pkgs, ... }:
{
  boot = {
    kernelParams = [
      "amd_iommu=on"
      "iommu=pt"
      "nvidia-drm.modeset=1"
      "intremap=on"
      "boot.shell_on_fail"
      "mitigations=off"
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
