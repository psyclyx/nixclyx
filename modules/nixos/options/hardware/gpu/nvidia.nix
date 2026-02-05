{nixclyx, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "hardware" "gpu" "nvidia"];
  description = "Nvidia GPU (currently 3090)";
  config = {config, ...}: {
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

    services.xserver.videoDrivers = ["nvidia"];
  };
} args
