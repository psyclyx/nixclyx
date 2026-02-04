{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.nixos.config.hosts.lab-1;
in {
  options.psyclyx.nixos.config.hosts.lab-1 = {
    enable = lib.mkEnableOption "lab-1 host";
  };

  config = lib.mkIf cfg.enable {
    networking.hostName = "lab-1";
    psyclyx.nixos = {
      filesystems.layouts.bcachefs-pool.UUID = {
        root = "4dbf5223-00ae-4cff-ad70-47e5e09d66e0";
        boot = "B320-71E8";
      };
    };
  };
}
