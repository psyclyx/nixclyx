{ ... }:
{
  psyclyx.boot.initrd-ssh.enable = true;

  boot = {
    initrd = {
      availableKernelModules = [
        "ahci"
        "xhci_pci"
        "virtio_pci"
        "virtio_scsi"
        "sd_mod"
        "sr_mod"
      ];
    };

    kernelModules = [ ];

    kernelParams = [ ];

    loader = {
      grub = {
        enable = true;
      };
    };
  };
}
