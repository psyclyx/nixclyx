{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.psyclyx.nixos.boot.systemd-initrd;
in
{
  options = {
    psyclyx.nixos.boot.systemd-initrd = {
      enable = mkEnableOption "systemd initrd";
    };
  };

  config = mkIf cfg.enable {
    boot.initrd = {
      systemd = {
        enable = true;
        network.enable = true;
      };
    };
  };
}
