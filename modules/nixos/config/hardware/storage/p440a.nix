{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.psyclyx.hardware.storage.p440a;
in
{
  options = {
    psyclyx.hardWare.storage.p440a = {
      enable = mkEnableOption "HPE P440 storage controller";
    };
  };

  config = mkIf cfg.enable {
    initrd.availableKernelModules = [ "hpsa" ];

    psyclyx.hardware.drivers.scsi = {
      enable = true;
      generic = true;
    };

    environment.systemPackages = [ inputs.self.packages.${pkgs.system}.ssacli ];
  };
}
