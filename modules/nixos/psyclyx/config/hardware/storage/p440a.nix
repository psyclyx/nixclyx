{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.hardware.storage.p440a;
in
{
  options = {
    psyclyx.hardware.storage.p440a = {
      enable = lib.mkEnableOption "HPE P440a(r) storage controller";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.initrd.availableKernelModules = [ "hpsa" ];
    psyclyx = {
      hardware.drivers.scsi.enable = true;
      nixos.programs.ssacli.enable = true;
    };
  };
}
