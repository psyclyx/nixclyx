{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.psyclyx.nixos.programs.ssacli;
in
{
  options = {
    psyclyx.nixos.programs.ssacli = {
      enable = mkEnableOption "HPE Smart Storage Array Command Line Interface";
    };
  };

  config = mkIf cfg.enable {
    boot.kernelModules = [ "sg" ];
    environment.systemPackages = [ pkgs.psyclyx.ssacli ];
  };
}
