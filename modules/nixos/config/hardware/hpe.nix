{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (inputs) self;
  inherit (lib)
    mkDefault
    mkEnableOption
    mkOption
    mkIf
    types
    ;

  cfg = config.psyclyx.hardware.hpe;
in
{
  options = {
    psyclyx.hardware.hpe = {
      enable = mkEnableOption "HPE-specific hardware configuration";
    };
  };

  config = mkIf cfg.enable {
    boot = {
      initrd.availableKernelModules = [
        "sd_mod"
        "sr_mod"
      ];
    };

    environment.systemPackages = [ self.packages.${pkgs.system}.ssacli ];
  };
}
