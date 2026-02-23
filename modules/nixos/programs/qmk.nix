{
  path = ["psyclyx" "nixos" "programs" "qmk"];
  description = "QMK";
  config = {pkgs, ...}: {
    environment.systemPackages = [
      pkgs.qmk
      pkgs.via
    ];

    hardware.keyboard.qmk.enable = true;
  };
}
