{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.nixos.programs.ssacli;
in
{
  options = {
    psyclyx.nixos.programs.ssacli = {
      enable = lib.mkEnableOption "HPE Smart Storage Array Command Line Interface";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [ "sg" ];
    environment.systemPackages = [ pkgs.psyclyx.ssacli ];
  };
}
