{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.nixos.hardware.storage.p408i-a-g10;
in {
  options = {
    psyclyx.nixos.hardware.storage.p408i-a-g10 = {
      enable = lib.mkEnableOption "HPE P408i-a-G10 storage controller";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.initrd.availableKernelModules = ["smartpqi"];
    psyclyx.nixos = {
      hardware.drivers.scsi.enable = true;
      programs.ssacli.enable = true;
    };
  };
}
