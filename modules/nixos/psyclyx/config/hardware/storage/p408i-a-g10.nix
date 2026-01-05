{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.hardware.storage.p408i-a-g10;
in
{
  options = {
    psyclyx.hardware.storage.p408i-a-g10 = {
      enable = lib.mkEnableOption "HPE P408i-a-G10 storage controller";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.initrd.availableKernelModules = [ "smartpqi" ];
    psyclyx = {
      hardware.drivers.scsi.enable = true;
      nixos.programs.ssacli.enable = true;
    };
  };
}
