{
  path = ["psyclyx" "nixos" "hosts" "lab-1"];
  variant = ["psyclyx" "nixos" "host"];
  config = {lib, ...}: {
    networking.hostName = "lab-1";
    psyclyx.nixos = {
      filesystems.layouts.zfs-pool = {
        enable = true;
        hostId = "bafe257f";
        boot.UUID = "B5E8-4785";
        arc.maxBytes = 206158430208; # 192GB
      };
    };
  };
}
