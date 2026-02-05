{
  path = ["psyclyx" "nixos" "hardware" "storage" "p440a"];
  description = "HPE P440a(r) storage controller";
  config = _: {
    boot.initrd.availableKernelModules = ["hpsa"];
    psyclyx.nixos = {
      hardware.drivers.scsi.enable = true;
      programs.ssacli.enable = true;
    };
  };
}
