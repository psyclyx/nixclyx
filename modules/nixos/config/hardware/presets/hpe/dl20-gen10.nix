{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.psyclyx.hardware.presets.hpe.dl360-gen9;
in
{
  options = {
    psyclyx.hardware.presets.hpe.dl20-gen9 = {
      enable = mkEnableOption "HPE ProLiant DL20 Gen 10";
    };
  };

  config = mkIf cfg.enable {
    psyclyx = {
      hardware = {
        cpu.intel.enable = true;

        drivers = {
          usb.enable = true;
          scsi.enable = true;
        };

        ipmi.ilo.enable = true;

        storage.p408i-a-g10.enable = lib.mkDefault true;
      };
    };
  };
}
