{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.psyclyx.nixos.system.containers;
in {
  options = {
    psyclyx.nixos.system.containers = {
      enable = lib.mkEnableOption "Container config";
      nvidia = lib.mkEnableOption "nvidia-container-tools for gpu-accelerated container support";
    };
  };

  config = lib.mkIf cfg.enable {
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
}
