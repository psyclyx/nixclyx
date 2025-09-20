{ config, lib, ... }:
let
  cfg = config.psyclyx.system.containers;
  nvidiaCfg = config.psyclyx.hardware.gpu.nvidia;
in
{
  options = {
    psyclyx.system.containers = {
      enable = lib.mkEnableOption "Container config";
      enableNvidia = lib.mkOption {
        default = nvidiaCfg.enable;
        description = "enable nvidia-container-tools for gpu-accelerated container support";
        type = lib.types.bool;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.nvidia-container-toolkit.enable = lib.mkIf cfg.enableNvidia true;
    virtualisation = {
      containers.enable = true;
      oci-containers.backend = "podman";
      podman = {
        enable = true;
        defaultNetwork.settings.dns_enabled = true;
      };
    };
  };
}
