{ inputs, pkgs, ... }:
{
  boot = {
    kernelParams = [
      "nvidia-drm.modeset=1"
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
