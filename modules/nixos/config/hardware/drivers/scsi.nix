{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf optionals;
  cfg = config.psyclyx.hardware.drivers.scsi;
in
{
  options = {
    psyclyx.hardware.drivers.scsi = {
      enable = mkEnableOption "SCSI drivers";
      cdRom = mkEnableOption "SCSI CD_ROM" // {
        default = true;
      };
      disk = mkEnableOption "SCSI Disk" // {
        default = true;
      };
      generic = mkEnableOption "SCSI Generic" // {
        default = true;
      };
    };
  };

  config = mkIf cfg.enable {
    boot.initrd.availableKernelModules =
      (optionals cfg.cdRom "sr_mod") ++ (optionals cfg.disk "sd_mod") ++ (optionals cfg.generic "sg");
  };
}
