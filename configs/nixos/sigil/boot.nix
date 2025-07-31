{ inputs, pkgs, ... }:
{
  boot = {
    kernelPackages = inputs.chaotic.unrestrictedPackages."${pkgs.system}".linuxPackages_cachyos;
    binfmt.emulatedSystems = [ "aarch64-linux" ];
    plymouth.enable = true;

    initrd = {
      verbose = false;
      systemd.enable = true;
    };

    loader = {
      timeout = 0;
      systemd-boot.enable = true;
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
