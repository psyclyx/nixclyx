{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.hardware.qmk;
in
{
  options = {
    psyclyx.hardware.qmk.enable = lib.mkEnableOption "QMK";
  };
  config = lib.mkIf cfg.enable {
    hardware.keyboard.qmk.enable = true;
    environment.systemPackages = with pkgs; [
      qmk
      via
    ];
  };
}
