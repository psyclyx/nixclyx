{ inputs, pkgs, ... }:
{
  boot = {
    kernelPackages = pkgs.linuxPackages_zen;

    initrd = {
      systemd.enable = true;
    };

    loader = {
      timeout = 0;
      systemd-boot = {
        enable = true;
        configurationLimit = 16;
      };
      efi.canTouchEfiVariables = true;
    };

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
