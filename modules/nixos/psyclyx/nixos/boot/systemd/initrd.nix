{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.nixos.boot.systemd.initrd;
in
{
  options = {
    psyclyx.nixos.boot.systemd.initrd = {
      enable = lib.mkEnableOption "systemd initrd";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.initrd = {
      systemd = {
        enable = true;
        network.enable = true;
      };
    };
  };
}
