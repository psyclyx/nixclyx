{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.psyclyx.hardware.storage.p408i-a-g10;
in
{
  options = {
    psyclyx.hardware.storage.p408i-a-g10 = {
      enable = mkEnableOption "HPE P408i-a-G10 storage controller";
    };
  };

  config = mkIf cfg.enable {
    boot.initrd.availableKernelModules = [ "smartpqi" ];

    psyclyx.hardware.drivers.scsi = {
      enable = true;
      generic = true;
    };

    environment.systemPackages = [ inputs.self.packages.${pkgs.system}.ssacli ];
  };
}
