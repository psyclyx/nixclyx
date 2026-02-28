{
  path = ["psyclyx" "nixos" "hosts" "lab-1"];
  variant = ["psyclyx" "nixos" "host"];
  config = {lib, ...}: {
    networking.hostName = "lab-1";
    psyclyx.nixos = {
      filesystems.layouts.zfs-pool = {
        enable = true;
        hostId = "bafe257f";
        boot.UUID = "8C79-5ABF";
        arc.maxBytes = 206158430208; # 192GB
      };
    };

    swapDevices = [
      { device = "/dev/disk/by-id/scsi-35000c500ca85744f-part2"; }
      { device = "/dev/disk/by-id/scsi-35000cca2550365c0-part2"; }
      { device = "/dev/disk/by-id/scsi-35000c500d723e9a7-part2"; }
      { device = "/dev/disk/by-id/scsi-35000cca25509a5a4-part2"; }
    ];
  };
}
