{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.psyclyx.nixos.programs.qmk;
in {
  options = {
    psyclyx.nixos.programs.qmk = {
      enable = lib.mkEnableOption "QMK";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.qmk
      pkgs.via
    ];

    hardware.keyboard.qmk.enable = true;
  };
}
