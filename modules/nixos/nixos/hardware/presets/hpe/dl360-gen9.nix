{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.nixos.hardware.presets.hpe.dl360-gen9;
in {
  options = {
    psyclyx.nixos.hardware.presets.hpe.dl360-gen9 = {
      enable = lib.mkEnableOption "HPE ProLiant DL360 Gen 9";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.initrd.availableKernelModules = [
      "mlx4_core"
      "tg3"
    ];

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
