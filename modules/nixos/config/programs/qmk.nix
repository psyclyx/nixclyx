{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.programs.qmk;
in
{
  options = {
    psyclyx.programs.qmk.enable = lib.mkEnableOption "QMK";
  };

  config = lib.mkIf cfg.enable {
    hardware.keyboard.qmk.enable = true;

    environment.systemPackages = with pkgs; [
      qmk
      via
    ];
  };
}
