{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.hardware.nvidia;
in
{
  options = {
    psyclyx.hardware.nvidia = {
      enable = lib.mkEnableOption "Nvidia GPU (currently 3090)";
    };
  };
  config = lib.mkIf cfg.enable {
    hardware.nvidia = {
      open = true;
      package = config.boot.kernelPackages.nvidiaPackages.production;
      powerManagement = {
        enable = true;
        finegrained = false;
      };
      modesetting.enable = true;
    };
    services.xserver.videoDrivers = [ "nvidia" ];
    # TODO: I don't think I actually need this? Check if wake from hiberate works
    # systemd.services."systemd-suspend" = {
    #   serviceConfig = {
    #     Environment = ''"SYSTEMD_SLEEP_FREEZE_USER_SESSIONS=false"'';
    #   };
  };
}
