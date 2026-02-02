{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.nixos.hardware.drivers.scsi;
in {
  options = {
    psyclyx.nixos.hardware.drivers.scsi = {
      enable = lib.mkEnableOption "SCSI drivers";
      cdRom =
        lib.mkEnableOption "SCSI CD_ROM"
        // {
          default = true;
        };
      disk =
        lib.mkEnableOption "SCSI Disk"
        // {
          default = true;
        };
      generic =
        lib.mkEnableOption "SCSI Generic"
        // {
          default = true;
        };
    };
  };

  config = lib.mkIf cfg.enable {
    boot.initrd.availableKernelModules =
      (lib.optionals cfg.cdRom ["sr_mod"])
      ++ (lib.optionals cfg.disk ["sd_mod"])
      ++ (lib.optionals cfg.generic ["sg"]);
  };
}
