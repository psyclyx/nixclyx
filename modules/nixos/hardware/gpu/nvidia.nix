{
  path = ["psyclyx" "nixos" "hardware" "gpu" "nvidia"];
  description = "Nvidia GPU (currently 3090)";
  config = {
    config,
    lib,
    ...
  }: {
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

    # A driver bump swaps userspace (libnvidia-ml) on switch, but the old
    # kernel module stays loaded until reboot, so NVML fails with
    # "Driver/library version mismatch" and the restarted generator fails
    # the switch. Leave the running unit alone instead: its spec matches
    # the loaded module, and it regenerates at boot (and via upstream's
    # --no-block udev rule) against the new one.
    systemd.services.nvidia-container-toolkit-cdi-generator =
      lib.mkIf config.hardware.nvidia-container-toolkit.enable {
        restartIfChanged = false;
      };
  };
}
