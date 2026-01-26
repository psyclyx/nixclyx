{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.nixos.hardware.storage.p440a;
in
{
  options = {
    psyclyx.nixos.hardware.storage.p440a = {
      enable = lib.mkEnableOption "HPE P440a(r) storage controller";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.initrd.availableKernelModules = [ "hpsa" ];
    psyclyx.nixos = {
      hardware.drivers.scsi.enable = true;
      programs.ssacli.enable = true;
    };
  };
}
