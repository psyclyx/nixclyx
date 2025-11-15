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
    psyclyx.hardware.storage.p440a = {
      enable = mkEnableOption "HPE P440a(r) storage controller";
    };
  };

  config = mkIf cfg.enable {
    boot.initrd.availableKernelModules = [ "hpsa" ];

    psyclyx.hardware.drivers.scsi = {
      enable = true;
      generic = true;
    };

    environment.systemPackages = [ inputs.self.packages.${pkgs.system}.ssacli ];
  };
}
