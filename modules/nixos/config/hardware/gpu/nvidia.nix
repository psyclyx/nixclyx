{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.hardware.gpu.nvidia;
in
{
  options = {
    psyclyx.hardware.gpu.nvidia = {
      enable = lib.mkEnableOption "Nvidia GPU (currently 3090)";
    };
  };
  config = lib.mkIf cfg.enable {
    hardware.nvidia = {
      modesetting.enable = true;
      open = true;
      package = config.boot.kernelPackages.nvidiaPackages.production;
      powerManagement.enable = true;
    };

    services.xserver.videoDrivers = [ "nvidia" ];

    systemd.services."systemd-suspend" = {
      serviceConfig = {
        Environment = ''"SYSTEMD_SLEEP_FREEZE_USER_SESSIONS=false"'';
      };
    };
  };
}
