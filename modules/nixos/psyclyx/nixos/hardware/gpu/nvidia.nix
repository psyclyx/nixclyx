{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.nixos.hardware.gpu.nvidia;
in
{
  options = {
    psyclyx.nixos.hardware.gpu.nvidia = {
      enable = lib.mkEnableOption "Nvidia GPU (currently 3090)";
    };
  };
  config = lib.mkIf cfg.enable {
    environment.variables = {
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      LIBVA_DRIVER_NAME = "nvidia";
      NIXOS_OZONE_WL = "1";
    };

    hardware.nvidia = {
      modesetting.enable = true;
      open = true;
      package = config.boot.kernelPackages.nvidiaPackages.production;
      powerManagement.enable = true;
    };

    services.xserver.videoDrivers = [ "nvidia" ];
  };
}
