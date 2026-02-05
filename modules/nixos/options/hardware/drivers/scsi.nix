{
  path = ["psyclyx" "nixos" "hardware" "drivers" "scsi"];
  description = "SCSI drivers";
  options = {lib, ...}: {
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
  config = {cfg, lib, ...}: {
    boot.initrd.availableKernelModules =
      (lib.optionals cfg.cdRom ["sr_mod"])
      ++ (lib.optionals cfg.disk ["sd_mod"])
      ++ (lib.optionals cfg.generic ["sg"]);
  };
}
