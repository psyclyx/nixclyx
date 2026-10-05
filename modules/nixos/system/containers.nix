{
  path = ["psyclyx" "nixos" "system" "containers"];
  description = "Container config";
  config = {
    config,
    lib,
    pkgs,
    ...
  }: {
    environment.systemPackages = [pkgs.distrobox];
    virtualisation = {
      containers.enable = true;
      oci-containers.backend = "podman";
      podman = {
        enable = true;
        enableNvidia = lib.mkDefault config.hardware.nvidia.enabled;
        defaultNetwork.settings.dns_enabled = true;
        dockerCompat = true;
      };
    };
  };
}
