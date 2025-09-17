{ pkgs, ... }:
{
  boot = {
    initrd = {
      availableKernelModules = [
        "i915"
      ];
    };

    kernelModules = [ "kvm-intel" ];

    kernelParams = [
      "i915.enable_psr=0" # screen flickering
    ];
  };
}
