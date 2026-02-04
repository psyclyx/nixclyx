{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.nixos.config.hosts.lab-2;
in {
  options.psyclyx.nixos.config.hosts.lab-2 = {
    enable = lib.mkEnableOption "lab-2 host";
  };

  config = lib.mkIf cfg.enable {
    networking.hostName = "lab-2";
    psyclyx.nixos = {
      filesystems.layouts.bcachefs-pool.UUID = {
        root = "2d2c95b3-cad6-4d9c-b11c-fe8abe7b8014";
        boot = "208E-CA68";
      };
    };
  };
}
