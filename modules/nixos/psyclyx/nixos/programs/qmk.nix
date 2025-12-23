{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.psyclyx.nixos.programs.qmk;
in
{
  options = {
    psyclyx.nixos.programs.qmk = {
      enable = mkEnableOption "QMK";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.qmk
      pkgs.via
    ];

    hardware.keyboard.qmk.enable = true;
  };
}
