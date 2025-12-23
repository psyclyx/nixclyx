{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkDefault mkEnableOption mkIf;
  cfg = config.psyclyx.nixos.system.containers;
in
{
  options = {
    psyclyx.nixos.system.containers = {
      enable = mkEnableOption "Container config";
      nvidia = mkEnableOption "nvidia-container-tools for gpu-accelerated container support";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.distrobox ];
    hardware.nvidia-container-toolkit.enable = cfg.nvidia;
    psyclyx.nixos.system.containers.nvidia = mkDefault config.hardware.nvidia.enabled;
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
