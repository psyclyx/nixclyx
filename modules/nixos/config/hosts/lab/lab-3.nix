{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.nixos.config.hosts.lab-3;
in {
  options.psyclyx.nixos.config.hosts.lab-3 = {
    enable = lib.mkEnableOption "lab-3 host";
  };

  config = lib.mkIf cfg.enable {
    networking.hostName = "lab-3";
    psyclyx.nixos = {
      filesystems.layouts.bcachefs-pool.UUID = {
        root = "46840ce1-f854-4a96-a9cb-f5a9de9a15fb";
        boot = "2DDC-9E1D";
      };
    };
  };
}
