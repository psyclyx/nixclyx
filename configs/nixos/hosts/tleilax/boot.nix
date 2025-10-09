{ ... }:
{
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
      network = {
        enable = true;
        udhcpc.enable = true;
        flushBeforeStage2 = true;
        ssh = {
          enable = true;
          port = 8022;
          authorizedKeys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEwUKqMso49edYpzalH/BFfNlwmLDmcUaT00USWiMoFO me@psyclyx.xyz"
          ];
          hostKeys = [ "/etc/secrets/initrd/ssh_host_key" ];
        };
        postCommands = ''
              # Automatically ask for the password on SSH login
          echo 'cryptsetup-askpass || echo "Unlock was successful; exiting SSH session" && exit 1' >> /root/.profile
        '';
      };
    };

    kernelModules = [ "kvm-intel" ];

    kernelParams = [ ];

    loader = {
      grub = {
        enable = true;
      };
    };
  };
}
