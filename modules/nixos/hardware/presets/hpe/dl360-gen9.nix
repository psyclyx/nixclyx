{
  path = ["psyclyx" "nixos" "hardware" "presets" "hpe" "dl360-gen9"];
  description = "HPE ProLiant DL360 Gen 9";
  config = {lib, ...}: {
    boot.initrd.availableKernelModules = [
      "bnx2x"
      "mlx4_core"
      "tg3"
    ];

    # bnx2x needs firmware from linux-firmware to actually bring up
    # the 10G NICs (otherwise the lab/storage VLAN interfaces fail
    # to initialise in stage-2).
    hardware.enableRedistributableFirmware = true;

    # iLO Virtual Serial Port on Gen9 is wired to BIOS COM2 = ttyS1.
    # Without console=ttyS1 + a getty on it, the entire boot is
    # invisible to anyone connected via iLO VSP.
    boot.kernelParams = [
      "console=tty0"
      "console=ttyS1,115200n8"
    ];
    systemd.services."serial-getty@ttyS1" = {
      enable = true;
      wantedBy = [ "multi-user.target" ];
    };

    psyclyx.nixos.hardware = {
      cpu.intel.enable = true;
      drivers = {
        usb.enable = true;
        scsi.enable = true;
      };

      ipmi.ilo.enable = true;
      storage.p440a.enable = lib.mkDefault true;
    };
  };
}
