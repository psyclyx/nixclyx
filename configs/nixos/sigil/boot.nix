{ inputs, pkgs, ... }:
{
  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
    plymouth.enable = true;

    initrd = {
      verbose = false;
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
      "quiet"
      "splash"
      "intremap=on"
      "boot.shell_on_fail"
      "udev.log_priority=3"
      "rd.systemd.show_status=auto"
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
