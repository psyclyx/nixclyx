{nixclyx, pkgs, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "programs" "qmk"];
  description = "QMK";
  config = _: {
    environment.systemPackages = [
      pkgs.qmk
      pkgs.via
    ];

    hardware.keyboard.qmk.enable = true;
  };
} args
