{
  path = ["psyclyx" "nixos" "hosts" "lab-4"];
  variant = ["psyclyx" "nixos" "host"];
  config = {lib, ...}: {
    networking.hostName = "lab-4";
    psyclyx.nixos = {
      filesystems.layouts.zfs-pool = {
        enable = true;
        hostId = "9924de5f";
        boot.UUID = "CF86-D5FF";
        arc.maxBytes = 85899345920; # 80GB
      };
    };
  };
}
