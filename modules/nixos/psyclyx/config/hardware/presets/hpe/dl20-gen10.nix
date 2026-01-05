{ config, lib, ... }:
let
  cfg = config.psyclyx.hardware.presets.hpe.dl20-gen10;
in
{
  options = {
    psyclyx.hardware.presets.hpe.dl20-gen10 = {
      enable = lib.mkEnableOption "HPE ProLiant DL20 Gen 10";
    };
  };

  config = lib.mkIf cfg.enable {
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
