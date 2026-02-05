{
  path = ["psyclyx" "nixos" "hardware" "storage" "p408i-a-g10"];
  description = "HPE P408i-a-G10 storage controller";
  config = _: {
    boot.initrd.availableKernelModules = ["smartpqi"];
    psyclyx.nixos = {
      hardware.drivers.scsi.enable = true;
      programs.ssacli.enable = true;
    };
  };
}
