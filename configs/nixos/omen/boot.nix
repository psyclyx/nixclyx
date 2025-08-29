{ pkgs, ... }:
{
  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
    binfmt.emulatedSystems = [ "aarch64-linux" ];
    initrd = {
      verbose = false;
      systemd.enable = true;
      availableKernelModules = [
        "xhci_pci"
        "ahci"
        "usb_storage"
        "sd_mod"
        "i915"
      ];
    };
    plymouth.enable = true;

    kernelModules = [ "kvm-intel" ];

    kernelParams = [
      "quiet"
      "splash"
      "intremap=on"
      "boot.shell_on_fail"
      "udev.log_priority=3"
      "rd.systemd.show_status=auto"
      "snd-intel-dspcfg.dsp_driver=1" # fix pipewire audio
      "i915.enable_psr=0" # screen flickering
      "mitigations=off"
    ];

    loader = {
      timeout = 0;
      systemd-boot = {
        enable = true;
      };
      efi = {
        canTouchEfiVariables = true;
      };
    };
  };
}
