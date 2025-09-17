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
      "snd-intel-dspcfg.dsp_driver=1" # fix pipewire audio
      "i915.enable_psr=0" # screen flickering
    ];
  };
}
