{nixclyx, lib, pkgs, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "system" "containers"];
  description = "Container config";
  options = {
    nvidia = lib.mkEnableOption "nvidia-container-tools for gpu-accelerated container support";
  };
  config = {cfg, config, ...}: {
    environment.systemPackages = [pkgs.distrobox];
    hardware.nvidia-container-toolkit.enable = cfg.nvidia;
    psyclyx.nixos.system.containers.nvidia = lib.mkDefault config.hardware.nvidia.enabled;
    virtualisation = {
      containers.enable = true;
      oci-containers.backend = "podman";
      podman = {
        enable = true;
        defaultNetwork.settings.dns_enabled = true;
        dockerCompat = true;
      };
    };
  };
} args
